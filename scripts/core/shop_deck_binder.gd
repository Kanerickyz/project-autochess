class_name ShopDeckBinder
extends RefCounted
## Binds shop / hand UI to ShopService + DeckState without owning game flow.

var shop_panel: ShopPanel
var hand_panel: HandPanel
var shop_service: ShopService
var deck_state: DeckState
var run_economy: RunEconomy


func configure(
	p_shop_panel: ShopPanel,
	p_hand_panel: HandPanel,
	p_shop_service: ShopService,
	p_deck_state: DeckState,
	p_economy: RunEconomy,
) -> void:
	shop_panel = p_shop_panel
	hand_panel = p_hand_panel
	shop_service = p_shop_service
	deck_state = p_deck_state
	run_economy = p_economy


func refresh_shop() -> void:
	if shop_panel == null or shop_service == null or run_economy == null:
		return
	shop_panel.refresh_slots(
		shop_service.get_character_offers(),
		shop_service.get_buff_offers(),
		run_economy.get_refresh_cost(),
		run_economy.gold,
	)


func refresh_hand(
	deployed_entry_ids: Dictionary,
	selected_entry_id: int,
	wave_hand_entries: Array[DeckEntry] = [],
	use_wave_hand: bool = false,
) -> void:
	if hand_panel == null or deck_state == null or run_economy == null:
		return
	if use_wave_hand:
		hand_panel.refresh_entries(
			wave_hand_entries,
			deck_state,
			deployed_entry_ids,
			selected_entry_id,
			run_economy.get_sell_price,
		)
	else:
		hand_panel.refresh_deck(
			deck_state,
			deployed_entry_ids,
			selected_entry_id,
			run_economy.get_sell_price,
		)
