extends RefCounted
const Store = preload("res://scripts/save_store.gd")
const Rules = preload("res://scripts/ranked_rules.gd")

static func pending_path(game: Control) -> String:
	return "user://ranked_pending_%s.json" % str(game.auth_user_id).sha256_text().substr(0,24)

static func pending_id(game: Control) -> String:
	var pending := Store.read_save(pending_path(game))
	return str(pending.get("id", "")) if pending.get("owner", "") == game.auth_user_id else ""

static func show_screen(game: Control, refresh := true) -> void:
	if game.ranked_owner != game.auth_user_id:
		game.ranked_state.clear()
	game.active_menu = "async"
	var content: VBoxContainer = game.begin_screen("多人積分賽", "真人快照對戰 · MMR 配對 · LP 升降 · 場次不限", 4)
	if game.auth_access.is_empty() or game.auth_user_id.is_empty():
		content.add_child(game.callout("登入後參賽", "多人賽需要雲端帳號。離線單人進度不受影響，不會用電腦隊伍冒充真人。", game.GOLD))
		content.add_child(game.action_button("前往登入", game.CYAN, func(): game.show_login()))
		return
	if refresh and not game.ranked_loading:
		request(game,"status",false)
	content.add_child(game.cloud_status_panel())
	if not str(game.ranked_message).is_empty():
		content.add_child(game.wrap_label(game.ranked_message, 14, game.GOLD))
	var state: Dictionary = game.ranked_state
	var season: Dictionary = state.get("season", {}) if state.get("season") is Dictionary else {}
	var closed := season.get("settled_at") != null
	content.add_child(game.wrap_label("結算：2026/12/1 00:00（台灣） · 已參賽 %d 隊" % int(state.get("participants", 0)), 13, game.MUTED))
	var mine: Dictionary = state.get("mine", {}) if state.get("mine") is Dictionary else {}
	var unresolved := not pending_id(game).is_empty()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	content.add_child(actions)
	if not mine.is_empty():
		var heading := "%s · %s" % [mine.get("club_name", "我的球隊"), Rules.rank_label(int(mine.get("lp", 0)))]
		content.add_child(game.callout(heading, "%d 勝 · %d 敗 · 本季 %d 場" % [int(mine.get("wins",0)),int(mine.get("losses",0)),int(mine.get("games",0))], game.GOLD))
		var lineup_button: Button = game.action_button("查看已登錄先發", game.CYAN, func(): show_lineup(game,mine))
		lineup_button.disabled = game.ranked_loading
		var details := HBoxContainer.new()
		details.add_theme_constant_override("separation",6)
		content.add_child(details)
		details.add_child(lineup_button)
		var history_button: Button = game.action_button("近期對戰紀錄",game.CYAN,func(): show_history(game))
		history_button.disabled = game.ranked_loading
		details.add_child(history_button)
	if not closed:
		var join: Button = game.action_button("更新參賽先發" if not mine.is_empty() and bool(mine.get("active",false)) else "報名參賽", game.ORANGE, func():
			game.show_guide_sheet("報名多人積分賽", "將公開目前俱樂部名稱及五位先發。離線時也會與其他參賽者配對，雙方戰績與 LP 都會升降。每個帳號一支參賽隊，更新名單不重設分數。\n\n無入場費、不扣資金／黃金／球探點。按下確認才會報名。", game.GOLD, "確認報名並公開先發",func(): game.close_guide_modal(); request(game,"join"))
		)
		join.disabled = game.ranked_loading or unresolved
		actions.add_child(join)
		if bool(mine.get("active",false)) or unresolved:
			var play: Button = game.action_button("取回未完成結果" if unresolved else "隨機配對開打",game.GREEN,func(): request(game,"play"))
			play.disabled = game.ranked_loading
			actions.add_child(play)
			if bool(mine.get("active",false)):
				var leave: Button = game.action_button("暫停參賽",game.MUTED,func(): request(game,"leave"))
				leave.disabled = game.ranked_loading or unresolved
				actions.add_child(leave)
		# Low-population fallback: players can practice immediately without waiting
		# for a server pairing. It never changes LP, resources, or season records.
		var practice: Button = game.action_button("快速練習（不影響排名）", game.CYAN, func(): game.quick_ranked_practice())
		practice.disabled = game.ranked_loading or unresolved
		actions.add_child(practice)
	elif unresolved:
		var recover: Button = game.action_button("取回截止前比賽結果",game.GREEN,func(): request(game,"play"))
		recover.disabled = game.ranked_loading
		actions.add_child(recover)
	var refresh_button: Button = game.action_button("更新排行",game.CYAN,func(): request(game,"status"))
	refresh_button.disabled = game.ranked_loading
	actions.add_child(refresh_button)
	content.add_child(game.wrap_label("每 100 LP 升一小階；每四小階升段，敗場也會降階。先發依伺服器保存的報名快照，不隨本機換隊自動改動。暫停參賽會退出配對與本季獎勵排名，戰績保留。",12,game.MUTED))
	var last: Variant = state.get("last_result")
	if last is Dictionary and not last.is_empty():
		var home: Dictionary = last.get("home", {})
		var away: Dictionary = last.get("away", {})
		content.add_child(game.callout("最近取回的對戰", "%s %d : %d %s\n%s · LP %+d" % [home.get("club_name","主隊"),int(last.get("home_score",0)),int(last.get("away_score",0)),away.get("club_name","客隊"),"勝利" if bool(last.get("won",false)) else "惜敗",int(last.get("lp_delta",0))],game.GREEN if bool(last.get("won",false)) else game.ORANGE))
		var opponent_button: Button = game.action_button("查看本場對手先發",game.CYAN,func(): show_lineup(game,away))
		opponent_button.disabled = game.ranked_loading
		content.add_child(opponent_button)
	var announcement: Variant = season.get("announcement", [])
	if closed:
		var lines := PackedStringArray()
		if announcement is Array:
			for winner in announcement:
				lines.append("第 %d 名　%s · %d LP" % [int(winner.get("place",0)),winner.get("club_name","俱樂部"),int(winner.get("lp",0))])
		content.add_child(game.callout("本季結算公告", "\n".join(lines) if not lines.is_empty() else "本季沒有符合資格的參賽隊伍。",game.GOLD))
	content.add_child(game.label("排行榜 · 點隊伍查看先發",16,game.GOLD,true))
	var board: Variant = state.get("leaderboard", [])
	if board is Array and not board.is_empty():
		for i in board.size():
			var entry: Dictionary = board[i]
			var row: Button = game.action_button("%d. %s · %s · %d勝%d敗" % [i+1,entry.get("club_name","俱樂部"),Rules.rank_label(int(entry.get("lp",0))),int(entry.get("wins",0)),int(entry.get("losses",0))],game.CYAN,func(): show_lineup(game,entry))
			row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.disabled = game.ranked_loading
			content.add_child(row)
	else:
		content.add_child(game.wrap_label("尚無已報名隊伍。配對不足時保留等待狀態，不會自動算輸。",13,game.MUTED))

static func show_history(game: Control) -> void:
	game.show_guide_sheet("近期對戰紀錄","最近 10 場，包含離線時的配對。點選紀錄查看對手當時先發。",game.CYAN)
	var box: Node = game.guide_modal.find_child("GuideSheetBody",true,false)
	var history: Variant = game.ranked_state.get("recent_matches",[])
	if not history is Array or history.is_empty():
		box.add_child(game.wrap_label("本季還沒有對戰紀錄。",14,game.MUTED))
		return
	for match_data in history:
		if not match_data is Dictionary:
			continue
		var opponent: Dictionary = match_data.get("opponent",{})
		var won := bool(match_data.get("won",false))
		var row: Button = game.action_button("%s  %d : %d  %s · LP %+d\n%s" % ["勝" if won else "敗",int(match_data.get("score_for",0)),int(match_data.get("score_against",0)),opponent.get("club_name","對手"),int(match_data.get("lp_delta",0)),"主動挑戰" if bool(match_data.get("initiated_by_me",false)) else "對手挑戰你的已登錄先發"],game.GREEN if won else game.ORANGE,func(): show_lineup(game,opponent))
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(row)

static func show_lineup(game: Control, entry: Dictionary) -> void:
	game.show_guide_sheet(str(entry.get("club_name","參賽隊伍")),Rules.rank_label(int(entry.get("lp",0))) ,game.CYAN)
	var box: Node = game.guide_modal.find_child("GuideSheetBody",true,false) if is_instance_valid(game.guide_modal) else null
	if box == null:
		return
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation",6)
	box.add_child(cards)
	var roster: Variant = entry.get("roster",[])
	if roster is Array:
		for player in roster:
			if not player is Dictionary:
				continue
			cards.add_child(game.lobby_player_card(player,false,-1,false,110,func():
				game.flash_notice("%s · %s · OVR %d" % [player.get("name","球員"),player.get("pos",""),int(player.get("ovr",0))])
			))

static func request(game: Control, action: String, redraw := true) -> void:
	if game.ranked_loading or game.auth_access.is_empty() or game.auth_user_id.is_empty():
		return
	if game.match_rewards_pending or game.current_stage == 6:
		game.flash_notice("請先完成目前比賽，再操作多人賽")
		return
	var payload := {"p_action":action}
	if action == "join":
		if game.cloud_restore_incomplete:
			game.flash_notice("請先完成雲端存檔同步，再報名多人賽")
			return
		if game.team_players.size() < 5 or game.over_salary_cap():
			game.flash_notice("請先編好五位先發，並確認沒有超過薪資上限")
			return
		game.save_game()
		game.flush_cloud_save(true)
		payload["p_slot"] = game.active_save_slot
		payload["p_team"] = game.active_team_index
		payload["p_expected"] = Rules.expected_roster(game.team_players)
	if action == "play":
		var id := pending_id(game)
		if id.is_empty():
			id = Rules.request_id()
			if Store.write_save(pending_path(game),{"owner":game.auth_user_id,"id":id}) != OK:
				game.flash_notice("無法保存比賽請求，尚未開打。請確認裝置空間。")
				return
		payload["p_request_id"] = id
	game.ranked_loading = true
	game.ranked_request_owner = game.auth_user_id
	game.ranked_message = "正在取得雲端排行…" if action == "status" else "正在處理多人賽…"
	game.cloud_send("ranked_"+action,game.SUPABASE_URL+"/rest/v1/rpc/godot_ranked",game.supabase_headers(true),HTTPClient.METHOD_POST,JSON.stringify(payload))
	if redraw and game.active_menu == "async":
		show_screen(game,false)

static func complete(game: Control, kind: String, code: int, body: String) -> void:
	game.ranked_loading = false
	if game.ranked_request_owner != game.auth_user_id or game.auth_user_id.is_empty():
		return
	var parser := JSON.new()
	if code < 200 or code >= 300 or parser.parse(body) != OK or not (parser.data is Dictionary) or not bool(parser.data.get("ok",false)):
		game.ranked_message = Rules.error_message(body)
	else:
		var previous: Variant = game.ranked_state.get("last_result")
		game.ranked_state = parser.data
		game.ranked_owner = game.auth_user_id
		if game.ranked_state.get("last_result") == null and previous is Dictionary:
			game.ranked_state["last_result"] = previous
		game.ranked_message = str(game.ranked_state.get("message",""))
		if kind == "ranked_play":
			if Store.write_save(pending_path(game),{"owner":game.auth_user_id,"id":""}) != OK:
				game.ranked_message += " · 本機待確認紀錄尚未清除；重試不會重複計分。"
		if bool(game.ranked_state.get("national_unlock",false)) and not game.national_unlocked:
			game.national_unlocked = true
			game.save_game()
			game.ranked_message += " · 本季前三名資格已確認，中華隊已解鎖！"
	if game.active_menu == "async" and game.current_stage != 6:
		show_screen(game,false)
