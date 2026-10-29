/* Balance report renderer — keep in sync with tools/sim_balance/report.js */
(function () {
  const chartInstances = {};

  document.getElementById("file").addEventListener("change", async (e) => {
    const f = e.target.files[0];
    if (!f) return;
    render(JSON.parse(await f.text()));
  });

  const runSelect = document.getElementById("runSelect");
  if (runSelect) {
    runSelect.addEventListener("change", () => {
      const path = runSelect.value;
      if (path) loadSummaryPath(path);
    });
  }

  init();

  async function init() {
    const manifest = await fetchJson("manifest.json");
    if (manifest && Array.isArray(manifest.runs) && manifest.runs.length > 0) {
      populateRunSelect(manifest);
      const latestId = manifest.latest_run_id;
      const entry =
        manifest.runs.find((r) => r.id === latestId) || manifest.runs[0];
      if (entry && entry.path) {
        runSelect.value = entry.path;
        const data = await fetchJson(entry.path);
        if (data) {
          render(data);
          return;
        }
      }
    }
    const fallback = await fetchJson("summary.json");
    if (fallback) {
      render(fallback);
      return;
    }
    document.getElementById("loadWarn").hidden = false;
  }

  async function loadSummaryPath(path) {
    const data = await fetchJson(path);
    if (data) render(data);
  }

  async function fetchJson(url) {
    try {
      const r = await fetch(url);
      if (!r.ok) return null;
      return await r.json();
    } catch (_) {
      return null;
    }
  }

  function populateRunSelect(manifest) {
    if (!runSelect) return;
    runSelect.innerHTML = manifest.runs
      .map((r) => {
        const label = [
          r.generated_at_utc || r.id,
          "v" + (r.game_version || "?"),
          r.run_count ? r.run_count + " runs" : "",
          r.git_ref ? "@" + r.git_ref : "",
        ]
          .filter(Boolean)
          .join(" · ");
        return (
          '<option value="' +
          escapeHtml(r.path) +
          '">' +
          escapeHtml(label) +
          "</option>"
        );
      })
      .join("");
    runSelect.hidden = false;
    const label = document.getElementById("runSelectLabel");
    if (label) label.hidden = false;
  }

  function formatKpi(kpi) {
    if (!kpi) return "—";
    const v = kpi.value;
    if (kpi.format === "percent") return (Number(v) * 100).toFixed(1) + "%";
    if (kpi.format === "floor") {
      const note = kpi.note ? " (" + kpi.note + ")" : "";
      return "F" + v + note;
    }
    return String(v ?? "—");
  }

  function render(summary) {
    document.getElementById("loadWarn").hidden = true;
    document.getElementById("root").hidden = false;

    const meta = summary.meta || {};
    const gameVer = summary.game_version || meta.game_version || "unknown";
    const schema = summary.report_schema_version || meta.report_schema_version || "?";
    document.getElementById("gameVersionBadge").innerHTML =
      '游戏版本 <strong>v' + escapeHtml(gameVer) + "</strong>";
    document.getElementById("schemaBadge").innerHTML =
      'Schema <strong>' + escapeHtml(schema) + "</strong>";

    document.getElementById("meta").textContent = [
      "runs=" + (summary.run_count ?? "?"),
      "seeds from " + (meta.seed_start ?? "?"),
      meta.generated_at_utc || "",
      meta.git_ref ? "ref=" + meta.git_ref : "",
      meta.github_sha ? "sha=" + meta.github_sha : "",
      "ai=" + (meta.ai_profile_id || summary.profile_id || "?"),
    ]
      .filter(Boolean)
      .join(" · ");

    const kpis = summary.kpis || [];
    const kpiRoot = document.getElementById("kpiCards");
    kpiRoot.innerHTML = kpis
      .filter((k) => k.id !== "game_version" && k.id !== "report_schema_version")
      .map(
        (k) =>
          '<div class="card"><div class="label">' +
          escapeHtml(k.label) +
          '</div><div class="value">' +
          escapeHtml(formatKpi(k)) +
          "</div></div>"
      )
      .join("");

    const floors = summary.by_floor || [];
    document.getElementById("floorTable").innerHTML = floors
      .map((r) => {
        const wr = (r.win_rate * 100).toFixed(1);
        const lr = ((r.loss_rate != null ? r.loss_rate : 1 - r.win_rate) * 100).toFixed(1);
        return (
          "<tr><td>" +
          r.floor +
          "</td><td>" +
          r.attempts +
          "</td><td>" +
          r.wins +
          "</td><td>" +
          wr +
          "%</td><td>" +
          lr +
          "%</td></tr>"
        );
      })
      .join("");

    destroyCharts();
    const mount = document.getElementById("chartMount");
    mount.innerHTML = "";
    const charts = summary.charts || buildLegacyCharts(summary);
    const specBody = document.getElementById("chartSpecTable");
    specBody.innerHTML = charts
      .map(
        (c) =>
          "<tr><td><code>" +
          escapeHtml(c.id) +
          "</code></td><td>" +
          escapeHtml(c.chart_type) +
          "</td><td>" +
          escapeHtml(c.title) +
          "</td><td>" +
          escapeHtml(c.description || "") +
          "</td></tr>"
      )
      .join("");

    charts.forEach((chart, idx) => {
      const block = document.createElement("div");
      block.className = "chart-block";
      block.innerHTML =
        "<h2>" +
        escapeHtml(chart.title) +
        "</h2>" +
        '<p class="chart-desc">' +
        escapeHtml(chart.description || "") +
        "</p>" +
        '<p class="axis-hint">X: ' +
        escapeHtml(chart.x_label || "") +
        " · Y: " +
        escapeHtml(chart.y_label || "") +
        "</p>";
      const canvas = document.createElement("canvas");
      canvas.id = "chart_" + idx;
      block.appendChild(canvas);
      mount.appendChild(block);
      renderChart(canvas, chart);
    });
  }

  function buildLegacyCharts(summary) {
    const floors = summary.by_floor || [];
    const labels = floors.map((r) => "F" + r.floor);
    const winRates = floors.map((r) => +(r.win_rate * 100).toFixed(1));
    const hist = summary.death_floor_histogram || {};
    const dLabels = Object.keys(hist).sort((a, b) => Number(a) - Number(b));
    return [
      {
        id: "encounter_win_rate_by_floor",
        title: "按地图层 · 遭遇胜率",
        chart_type: "bar",
        x_label: "地图层号",
        y_label: "胜率 (%)",
        description: "legacy by_floor",
        labels,
        datasets: [{ label: "遭遇胜率 %", values: winRates }],
      },
      {
        id: "death_floor_histogram",
        title: "败局 · 死亡地图层分布",
        chart_type: "bar",
        labels: dLabels.map((x) => "F" + x),
        datasets: [{ label: "败局 Run 数", values: dLabels.map((k) => hist[k]) }],
      },
    ];
  }

  function renderChart(canvas, chart) {
    const type = chart.chart_type === "line" ? "line" : chart.chart_type === "doughnut" ? "doughnut" : "bar";
    const datasets = (chart.datasets || []).map((ds, i) => {
      const colors = ["#5b8def", "#e57373", "#81c784", "#ffb74d", "#ba68c8"];
      const c = colors[i % colors.length];
      return {
        label: ds.label,
        data: ds.values,
        backgroundColor: type === "line" ? c + "33" : c,
        borderColor: c,
        borderWidth: type === "line" ? 2 : 0,
        fill: type === "line",
        tension: 0.25,
      };
    });
    const options = {
      plugins: { legend: { display: datasets.length > 1 || type === "doughnut" } },
      scales: {},
    };
    if (type !== "doughnut") {
      options.scales = {
        y: {
          beginAtZero: true,
          title: { display: !!chart.y_label, text: chart.y_label },
        },
        x: { title: { display: !!chart.x_label, text: chart.x_label } },
      };
      if (chart.y_label && chart.y_label.includes("%")) {
        options.scales.y.max = 100;
      }
    }
    chartInstances[canvas.id] = new Chart(canvas, {
      type,
      data: { labels: chart.labels, datasets },
      options,
    });
  }

  function destroyCharts() {
    Object.keys(chartInstances).forEach((id) => {
      chartInstances[id].destroy();
      delete chartInstances[id];
    });
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }
})();
