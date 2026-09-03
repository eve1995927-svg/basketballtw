extends Control

# 台籃模擬器：SBL 開局 → 季後賽 → PLG/TPBL → 東超/BCL。隊名依官方名稱。

const SaveStore = preload("res://scripts/save_store.gd")
const TeamCareer = preload("res://scripts/team_career.gd")
const RankedRules = preload("res://scripts/ranked_rules.gd")
const RankedFlow = preload("res://scripts/ranked_flow.gd")
const CloudSync = preload("res://scripts/cloud_sync.gd")
const LocalProfiles = preload("res://scripts/local_profiles.gd")
const DraftCatalog = preload("res://scripts/draft_catalog.gd")
const MatchSimulator = preload("res://scripts/match_simulator.gd")
const PlayoffSeries = preload("res://scripts/playoff_series.gd")
var playoff_state: Dictionary = {}
const SCOUT_REFRESH_GOLD := 20
var draft_state: Dictionary = {}
var drafted_prospect_ids: Array = []
var duplicate_notices: Array[String] = []
var prep_extra_event := ""
const PlayerCardVisual = preload("res://scripts/player_card_visual.gd")
const BasketballCourtBoard = preload("res://scripts/basketball_court_board.gd")
const ButtonSkin = preload("res://scripts/button_skin.gd")

# Lightweight, code-drawn light cracks for card-tier promotion. Keeping this as
# a Control avoids a full-screen shader and keeps the reveal cheap on phones.
class TierUpCracks extends Control:
	var accent := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var paths := [
			[Vector2(w * 0.50, h * 0.06), Vector2(w * 0.43, h * 0.25), Vector2(w * 0.51, h * 0.43), Vector2(w * 0.39, h * 0.65)],
			[Vector2(w * 0.05, h * 0.38), Vector2(w * 0.25, h * 0.42), Vector2(w * 0.39, h * 0.54)],
			[Vector2(w * 0.95, h * 0.31), Vector2(w * 0.73, h * 0.39), Vector2(w * 0.58, h * 0.54)],
			[Vector2(w * 0.57, h * 0.55), Vector2(w * 0.68, h * 0.72), Vector2(w * 0.61, h * 0.93)],
		]
		for path in paths:
			for i in range(path.size() - 1):
				draw_line(path[i], path[i + 1], Color(accent, 0.18), 7.0, true)
				draw_line(path[i], path[i + 1], Color(accent, 0.92), 1.8, true)
		for point in [Vector2(w * 0.39, h * 0.54), Vector2(w * 0.58, h * 0.54)]:
			draw_circle(point, 13.0, Color(accent, 0.10))
			draw_circle(point, 3.0, Color(1, 1, 1, 0.92))
# Compact phone controls: keep the label size, reduce the surrounding box.
# 44 is the practical touch floor; going to a literal 40 would reintroduce missed taps.
const MOBILE_TOUCH_SIZE := 44.0
# 全部對手球員的固定難度加成。只套用在對手複本，不會改到玩家名單或原始資料。
const OPPONENT_OVR_BONUS := 5

const SAVE_PATH := "user://taiwan_basketball_save.json"
const AUDIO_SETTINGS_PATH := "user://audio_settings.json"
const ACCOUNT_PATH := "user://taiwan_basketball_account.json"
const AUTH_PATH := "user://taiwan_basketball_auth.json"
const CAREER_PATH := "res://data/career.json"
const LEGAL_NOTICE_TITLE := "遊戲聲明與權利說明"
const LEGAL_NOTICE_TEXT := "本遊戲為獨立開發的體育模擬器，非官方聯盟或球隊產品。\n\n遊戲中部分隊名、球員名稱與賽事名稱參考真實籃球資訊，並非全部虛構。球員能力、卡片稀有度、遊戲薪資、交易、陣容及比賽結果屬於遊戲模擬設定，不代表真實人物的實際表現、合約、行為或官方評價。\n\n本遊戲與任何真實職業籃球聯盟、球隊或球員無官方授權、合作、贊助或背書關係。\n\n遊戲所涉及的名稱、商標、隊徽、照片、肖像及其他素材之相關權利，仍屬各該權利人。本聲明不構成素材使用授權，也不表示相關使用當然合法或免除依法應負的責任。\n\n本說明不要求使用者放棄依法享有的權利。\n\n更新日期：2026 年 8 月 31 日"
const SUPABASE_URL := "https://oqvvtjmgasdnherqbllh.supabase.co"
const SUPABASE_ANON := "sb_publishable_oDE8MMcMCvM2qnmmsYLG8Q_m605nr3h"
const APP_VERSION := "0.9.4"
const AUTH_REDIRECT := "http://127.0.0.1:8765/callback"
const STYLIZED_ART := [
	"res://assets/art/hero_pg.png",
	"res://assets/art/hero_sg.png",
	"res://assets/art/hero_sf.png",
	"res://assets/art/hero_pf.png",
	"res://assets/art/hero_c.png",
	"res://assets/art/hero_wing.png",
]
const CLUB_LOGOS := [
	{"id": "club_01", "name": "烈焰"}, {"id": "club_02", "name": "雷霆"}, {"id": "club_03", "name": "海浪"},
	{"id": "club_04", "name": "山脈"}, {"id": "club_05", "name": "黑豹"}, {"id": "club_06", "name": "金鷹"},
	{"id": "club_07", "name": "赤龍"}, {"id": "club_08", "name": "霜狼"}, {"id": "club_09", "name": "橘虎"},
	{"id": "club_10", "name": "翠鳳"}, {"id": "club_11", "name": "紫晶"}, {"id": "club_12", "name": "白鶴"},
	{"id": "club_13", "name": "赤狐"}, {"id": "club_14", "name": "藍鯨"}, {"id": "club_15", "name": "星河"},
	{"id": "club_16", "name": "熔岩"}, {"id": "club_17", "name": "竹風"}, {"id": "club_18", "name": "夜隼"},
	{"id": "club_19", "name": "銀月"}, {"id": "club_20", "name": "珊瑚"}, {"id": "club_21", "name": "玄龜"},
	{"id": "club_22", "name": "疾風"}, {"id": "club_23", "name": "琥珀"}, {"id": "club_24", "name": "墨影"},
	{"id": "club_25", "name": "曙光"}, {"id": "club_26", "name": "銀河"}, {"id": "club_27", "name": "岩盾"},
	{"id": "club_28", "name": "霓虹"}, {"id": "club_29", "name": "青鋒"}, {"id": "club_30", "name": "赤焰輪"},
]
const NAV_ICONS := {
	"roster": "res://assets/ui/icons/roster.png",
	"market": "res://assets/ui/icons/market.png",
	"collection": "res://assets/ui/icons/collection.png",
	"more": "res://assets/ui/icons/more.png",
	"match": "res://assets/ui/icons/match.png",
	"guide": "res://assets/ui/icons/guide.png",
	"news": "res://assets/ui/icons/news.png",
	"save": "res://assets/ui/icons/save.png",
	"vault": "res://assets/ui/icons/nav_vault.png",
}
const HUB_ART := {
	"roster": "res://assets/art/lobby/roster.png",
	"market": "res://assets/art/lobby/market.png",
	"collection": "res://assets/art/lobby/collection.png",
	"more": "res://assets/art/lobby/more.png",
	"match": "res://assets/art/lobby/match.png",
	"guide": "res://assets/art/lobby/guide.png",
	"news": "res://assets/art/lobby/news.png",
	"save": "res://assets/art/lobby/save.png",
	"shared": "res://assets/art/lobby/tile_shared.png",
}
const STORE_ICONS := {
	"save_slot": "res://assets/ui/store/save_slot.png",
	"referral": "res://assets/ui/store/referral.png",
	"easl": "res://assets/ui/store/easl.png",
	"jones": "res://assets/ui/store/jones.png",
	"national": "res://assets/ui/store/national.png",
}
const SHOW_OFFICIAL_PHOTOS := false
const FONT_REGULAR: FontFile = preload("res://assets/fonts/NotoSansTC-Regular.otf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/NotoSansTC-Bold.otf")
const FONT_NUMBER_FILE: FontFile = preload("res://assets/fonts/BarlowCondensed-ExtraBold.ttf")
const FONT_KICKER_FILE: FontFile = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const SALARY_CAP_START := 3000
const SALARY_CAP_SBL := 3000
const SALARY_CAP_PRO := 8000
const PLAYER_SALARY_MIN := 100
const PLAYER_SALARY_MAX := 3000
const WIN_CAP_GAIN := 20
const ECONOMY_VERSION := 1
const ECONOMY_COMPENSATION := 1000
const STARTING_BUDGET_MILLION := 300
const STARTING_GOLD := 100
const STARTING_SCOUT_POINTS := 20
const STARTING_TRAINING_POINTS := 0
const TRAINING_MAX_SESSIONS := 5
const STARTING_SALARY_CAP := 3000
const UI_TOP_BAR_HEIGHT_PHONE := 44
const UI_TOP_BAR_HEIGHT_DESKTOP := 56
const UI_BOTTOM_BAR_HEIGHT_PHONE := 58
const UI_BOTTOM_BAR_HEIGHT_DESKTOP := 52
const UI_RESOURCE_CHIP_HEIGHT_PHONE := 44
const UI_RESOURCE_CHIP_HEIGHT_DESKTOP := 52
const UI_RESOURCE_CHIP_WIDTH_PHONE := 88
const UI_RESOURCE_CHIP_WIDTH_PHONE_SALARY := 168
const UI_RESOURCE_CHIP_WIDTH_DESKTOP := 104
const UI_RESOURCE_CHIP_WIDTH_DESKTOP_SALARY := 176
const UI_RESOURCE_ICON_PHONE := 14
const UI_RESOURCE_ICON_DESKTOP := 24
const UI_PLAYER_FACE_PHONE := Vector2(136, 180)
const UI_PLAYER_FACE_DESKTOP := Vector2(172, 228)
const UI_PLAYER_SHEET_GAP_PHONE := 10
const UI_PLAYER_SHEET_GAP_DESKTOP := 14
const UI_MATCH_COURT_HEIGHT_PHONE := 280
const UI_MATCH_COURT_HEIGHT_DESKTOP := 260
const UI_MARKET_CARD_WIDTH_PHONE := 136
const UI_MARKET_CARD_WIDTH_DESKTOP := 112
const UI_SCOUT_GRID_GUTTER := 56
const MAX_TEAM_PROFILES := 3
const AVAILABLE_TEAM_PROFILES := 2
const BGM_TRACK_NAMES := ["大廳", "嘻哈", "夜場"]
const STARTER_SLOTS := ["PG", "SG", "SF", "PF", "C"]
const SCOUT_RARITY_PROBABILITIES := [
	{"id": "gold", "name": "黃金卡", "percent": 1},
	{"id": "purple", "name": "紫色卡", "percent": 5},
	{"id": "red", "name": "紅色卡", "percent": 10},
	{"id": "blue", "name": "藍色卡", "percent": 20},
	{"id": "green", "name": "綠色卡", "percent": 30},
	{"id": "cyan", "name": "青色卡", "percent": 34},
]
# 公開登錄／生涯常見雙能，其餘維持單一位置。不要靠技能亂加第二位置。
const NATURAL_DUAL := {
	"蔣淯安": ["PG", "SG"],
	"林庭謙": ["PG", "SG"],
	"劉錚": ["SG", "SF"],
	"陳將双": ["SG", "PG"],
	"周桂羽": ["SF", "SG"],
	"阿巴西": ["SF", "PF"],
	"林志傑": ["SF", "SG"],
	"賀丹": ["SF", "PF"],
}
const FICTIONAL_TEAM_NAMES := {
	"fubon": "台北悍將",
	"dea": "新北特工",
	"kings": "新北皇家",
	"pilots": "桃園飛行員",
	"lioneers": "新竹狂獅",
	"dreamers": "寶島追逐者",
	"aquas": "高雄波賽頓",
	"ghosthawks": "台南飛鷹",
	"yankey": "新竹洋基",
	"mars": "台北戰士",
	"leopards": "桃園黑豹",
	"sbl_beer": "台灣烈酒",
	"sbl_bank": "台灣金控",
	"sbl_yulon": "裕隆恐龍",
	"sbl_pure": "彰化柏力力",
	"sbl_kites": "基隆雷鳥",
}
const ACHIEVEMENT_BADGES := [
	{"id":"home_fan", "name":"資深主場迷", "hint":"累積 10 場主場比賽"},
	{"id":"oracle", "name":"神算大師", "hint":"勝負預測命中 10 次"},
	{"id":"sniper", "name":"三分狙擊手", "hint":"單場投進 8 顆三分"},
	{"id":"rim_guardian", "name":"禁區守護者", "hint":"單季場均 8 籃板"},
	{"id":"comeback", "name":"逆轉之王", "hint":"末節落後仍完成逆轉"},
	{"id":"streak_hunter", "name":"連勝獵人", "hint":"完成 5 連勝"},
	{"id":"iron_captain", "name":"鐵人隊長", "hint":"單季出賽 20 場"},
	{"id":"scout_eye", "name":"新秀伯樂", "hint":"簽下 5 名新人"},
	{"id":"champion", "name":"冠軍教練", "hint":"贏得一座聯盟冠軍"},
	{"id":"basketball_wiki", "name":"台籃百科", "hint":"查看所有聯盟資料"},
]
const TEAM_MARK := {
	"sbl_pure": "柏",
	"sbl_kites": "雷",
	"sbl_bank": "銀",
	"sbl_beer": "啤",
	"sbl_yulon": "裕",
	"nt_japan": "日",
	"nt_china": "中",
	"nt_korea": "韓",
	"nt_taipei": "華",
	"nt_jordan": "約",
	"nt_malaysia": "馬",
	"jones_db": "原",
	"jones_uci": "加",
	"jones_sga": "菲",
	"fubon": "勇",
	"pilots": "猿",
	"ghosthawks": "鷹",
	"yankey": "洋",
	"dea": "攻",
	"aquas": "海",
	"mars": "神",
	"leopards": "豹",
	"lioneers": "獅",
	"dreamers": "家",
	"kings": "王",
}
const TEAM_SHORT := {
	"sbl_pure": "彰化柏力力",
	"sbl_kites": "基隆雷鳥",
	"sbl_bank": "台灣金控",
	"sbl_beer": "台灣烈酒",
	"sbl_yulon": "裕隆恐龍",
	"fubon": "台北悍將",
	"pilots": "桃園飛行員",
	"ghosthawks": "台南飛鷹",
	"yankey": "新竹洋基",
	"dea": "新北特工",
	"aquas": "高雄波賽頓",
	"mars": "台北戰士",
	"leopards": "桃園黑豹",
	"lioneers": "新竹狂獅",
	"dreamers": "寶島追逐者",
	"kings": "新北皇家",
}
# Roster moves are applied to old cloud/local saves by name as well as to the
# catalog, so an existing card follows the player's current club immediately.
const PLAYER_TEAM_OVERRIDES := {
	"高國豪": "ghosthawks",
	"陳昱瑞": "pilots",
}

const BG := Color("07111c")
const SURFACE := Color("0d1b2a")
const SURFACE_2 := Color("142b3d")
const TAIWAN_BLUE := Color("1b4965")
const TAIWAN_CYAN := Color("2ec4c7")
const ORANGE := Color("f26b21")
const ORANGE_2 := Color("ffad5a")
const CYAN := Color("64d9ff")
const GREEN := Color("55d6a0")
const TEXT := Color("f6f8fb")
const MUTED := Color("9aafc1")
const RED := Color("ed5b62")
const GOLD := Color("f5c451")
const PANEL_LINE := Color("2b5268")
const PURPLE := Color("c45cff")
const DIAMOND := Color("d6f4ff")
# Skill balance guardrails. These are efficiency units used by the simulator,
# not direct score or win guarantees: one normal card is kept below roughly
# six win-rate percentage points, while a full lineup is capped at about 12.
const SKILL_INDIVIDUAL_OFFENSE_CAP := 0.60
const SKILL_INDIVIDUAL_DEFENSE_CAP := 0.60
const SKILL_INDIVIDUAL_Q4_CAP := 0.75
const SKILL_TEAM_OFFENSE_CAP := 0.72
const SKILL_TEAM_DEFENSE_CAP := 0.72
const SKILL_TEAM_Q4_CAP := 0.90
const FAN_SKILL_NAMES := {
	"盧峻翔": "69大魔王",
	"林志傑": "野獸覺醒",
	"陳信安": "台灣飛人",
	"田壘": "少俠出劍",
	"曾文鼎": "大房東收租",
	"楊敬敏": "阿美族戰士",
	"李學林": "寶島艾佛森",
	"張宗憲": "噴射機起飛",
	"蔡文誠": "本土洋將",
	"林庭謙": "中華隊救星",
	"高國豪": "小鋼炮",
	"高錦瑋": "高砲開火",
	"阿巴西": "黑豹突襲",
	"蔣淯安": "安佛森變速",
	"林俊吉": "板凳核彈",
	"胡瓏貿": "鋒線萬用膠",
	"林書緯": "冷面司令",
	"李德威": "台灣魔獸",
	"馬建豪": "台灣KD",
	"林韋翰": "球場魔術師",
	"李愷諺": "新北飆風玫瑰",
	"陳冠全": "中華隊最愛",
}
const WEB_NEWS_PATH := "user://taiwan_basketball_webnews.json"
const WEB_NEWS_RSS := "https://news.google.com/rss/search?q=SBL+OR+PLG+OR+TPBL+OR+%E5%8F%B0%E7%81%A3%E7%B1%83%E7%90%83&hl=zh-TW&gl=TW&ceid=TW:zh-Hant"
const LINE_QR_PATH := "res://assets/ui/line_community_qr.jpg"
const PUBLIC_PLAYERS_PATH := "res://data/players_public.json"
const LEAGUE_TEAMS_PATH := "res://data/league_teams.json"
const NATIONAL_TEAMS_PATH := "res://data/national_teams.json"
const JONES_CUP_PATH := "res://data/jones_cup.json"
const EXTRA_ROSTERS_PATH := "res://data/extra_team_rosters.json"
const TACTIC_RULES_PATH := "res://data/tactic_matchups.json"

var current_stage := 0
var active_menu := "dashboard"
var return_stack: Array = []
var salary_return_menu := "dashboard"
var public_players: Array[Dictionary] = []
var league_teams: Array[Dictionary] = []
var national_teams: Array[Dictionary] = []
var world_cup_meta: Dictionary = {}
var jones_cup_meta: Dictionary = {}
var extra_team_rosters: Dictionary = {}
var tactic_kind_filter := "進攻"
var last_skill_event := "尚未觸發特殊技能"
var last_news := "自由建隊啟程：選好頭號球星，準備打造你的球隊。"
var trade_notice_pending := false
var market_candidates: Array[Dictionary] = []
var gacha_candidates: Array[Dictionary] = []
var gacha_opened := 0
var scout_pity_progress := 0
var scout_board_serial := 0
var supporter_theme := "標準球館"
var store_cosmetics_owned: Array[String] = ["standard"]
var store_category := "精選"
var store_selected_product := "arena_taipei"
var home_environment_mode := "arena"
var home_schedule_preview_offset := 0
var locker_room_theme := "標準更衣室"
var vault_capacity_bonus := 0
var second_team_unlocked := false
var active_challenge := ""
var challenge_progress: Dictionary = {"small_market":0, "salary_cap":0, "national_pride":0}
var challenge_completed: Dictionary = {"small_market":false, "salary_cap":false, "national_pride":false}
var mission_alert := false
var daily_checkin_date := ""
var daily_checkin_streak := 0
var daily_checkin_days := 0
var monthly_pass_active := false
var monthly_pass_claimed_date := ""
var monthly_pass_claimed_days := 0
var scout_free_refresh_date := ""
var prediction_match_key := ""
var prediction_pick := ""
var prediction_margin := ""
var prediction_stake := 0
var prediction_points := 0
var prediction_correct := 0
var prediction_badges: Array[String] = []
var equipped_badges: Array[String] = []
var activity_cloud_schedule: Array[Dictionary] = []
var activity_cloud_leaderboard: Array[Dictionary] = []
var activity_league_filter := "全部"
var async_season_active := false
var async_season_game := 0
var async_season_wins := 0
var async_season_losses := 0
var async_season_points := 0
var async_season_roster_snapshot: Array[Dictionary] = []
var async_season_settled_key := ""
var ranked_state: Dictionary = {}
var ranked_loading := false
var ranked_message := ""
var ranked_owner := ""
var ranked_request_owner := ""
var last_progress_event := "免費核心玩法已開放：比賽、交易、選秀、收藏與中華隊都能靠遊戲內進度體驗。"
var national_tournament := "2025 亞洲盃資格賽"
var national_roster: Array[Dictionary] = []
var national_registered := false
var national_games := 0
var national_wins := 0
var national_last_result := "尚未出賽"
var tactic_rules: Dictionary = {}
var current_skill_modifiers: Dictionary = {}
var match_event_log: Array[String] = []
var club_name := "未命名俱樂部"
var club_logo_id := "club_01"
var active_team_index := 0
var team_profiles: Array[Dictionary] = []
var selected_foundation := 0
var roster_batch_mode := false
var roster_batch_selected: Dictionary = {}
var roster_filters_visible := false
var roster_filter_pos := ""
var roster_filter_origin := ""
var roster_filter_ovr := 0
var roster_filter_kind := "pos"
var vault_filters_visible := false
var vault_filter_pos := ""
var vault_filter_origin := ""
var vault_filter_ovr := 0
var vault_filter_kind := "pos"
var vault_filter_tier := ""
var vault_sort_mode := "ovr_desc"
var market_filter_pos := ""
var market_filter_origin := ""
var market_filter_ovr := 0
var market_filter_kind := "pos"
var trade_list_shown := 12
var fa_list_shown := 12
var trade_out_indices: Array[int] = []
var trade_incoming: Dictionary = {}
var trade_modal: Control
var selected_tactic := "快節奏轉換"
var selected_defense := "人盯人"
var match_defense_changed := false
var match_defense_menu := false
var scout_floor_game := -1
var is_home_game := true
var season_wins := 0
var season_losses := 0
var season_games := 0
var chemistry := 48
var budget_million := 300
var economy_version := ECONOMY_VERSION
var scout_points := 20
var phone_bench_scroll := 0
var resource_hud_elapsed := 0.0
var resource_hud_labels: Dictionary = {}
var resource_hud_snapshot: Array = []
var training_points := 2
var opponent_index := 0
var live_choices: Array[Dictionary] = []
var selected_live_player := ""
var last_score: Array[int] = [0, 0]
var quarter_scores: Array = [[], []]
var reveal_quarter := 0
var last_mvp := "楊天佑"
var last_box := {"pts": 24, "reb": 5, "ast": 8}
var last_event := "球隊就緒。去大廳打第一場吧。"
var last_match_played := false
var match_rewards_pending := false
var match_play_id := 0
var server_settlement_inflight := false
var server_settlement_ready := false
var server_settlement_balance: Dictionary = {}
var server_settlement_match_id := ""
var server_spend_inflight := false
var server_spend_authorized := false
var server_spend_balance: Dictionary = {}
var server_spend_request_id := ""
var server_spend_callback: Callable
var release_gate_pending := false
var release_gate_checked := false
var release_gate_blocked := false
var notice_node: Control
var training_modal: Control
var guide_modal: Control
var _tex_cache: Dictionary = {}
var _tex_miss: Dictionary = {}
var _bust_cache: Dictionary = {}
var _font_display: FontVariation
var _font_number: FontVariation
var _font_kicker: FontVariation
var sfx_player: AudioStreamPlayer
var bgm_player: AudioStreamPlayer
var sfx_on := true
var bgm_on := true
var bgm_volume := 0.28
var bgm_track := 0
var _bgm_cache: Dictionary = {}
var cloud_http: HTTPRequest
var auth_server: TCPServer
var auth_access := ""
var auth_refresh := ""
var auth_user_id := ""
var auth_email := ""
var login_email := ""
var login_otp := ""
var otp_retry_at_ms := 0
var cloud_pending := ""
var cloud_generation := 0
var cloud_refresh_attempted := false
var cloud_queue: Array = []
var cloud_active: Dictionary = {}
var cloud_failed: Dictionary = {}
var cloud_retry_count := 0
var cloud_retry_at_ms := 0
var cloud_started_at_ms := 0
var cloud_status := ""
var cloud_status_widgets: Array[Control] = []
var cloud_restore_incomplete := false
var cloud_local_baseline: Dictionary = {}
var cloud_restore_conflict := false
var sync_owner := ""
var sync_state: Dictionary = {}
var sync_seen: Array = []
var sync_error := false
var sync_applied_active := false
var sync_read_complete := false
var local_profile_id := ""
const CLOUD_MAX_RETRIES := 2
var cloud_fail_notice_shown := false
var _cloud_dirty := false
var _cloud_account_dirty := false
var _app_suspended := false
var _foreground_fps := 60
var _iap_poll_elapsed := 0.0
var _save_failed_notice := false
var _settling_match := false
var _resume_tree := false
var _safe_pad_last := Vector4i(-1, -1, -1, -1)
var _safe_pad_elapsed := 0.0
var _cloud_idle := 0.0
var _cloud_held := 0.0
var pending_enter_after_auth := false
var welcome_open := false
var tutorial_seen := false
var career_rules: Dictionary = {}
var active_save_slot := 0
var extra_save_unlocked := false
var extra_save_bought := 0
var referral_code := ""
var referral_entered := ""
var referral_count := 0
var referral_slot_granted := false
var lin_hidden_granted := false
var easl_pass := false
var jones_pass := false
var extra_match := false
var extra_event := ""
var extra_entry := ""
var extra_wins := 0
var extra_queue: Array = []
var extra_champions: Dictionary = {}
var extra_runs: Dictionary = {}
var pending_card_reveal: Dictionary = {}
var card_reveal_modal: Control
var card_reveal_then: Callable = Callable()
var share_modal: Control
var share_export_busy := false
var pro_top2 := false
var difficulty_level := 0
var national_event := "jones_white"
var national_progress := "jones_white"
var last_pro_league := "SBL"
var pending_enter_league := ""
var gold := 100
var salary_cap := STARTING_SALARY_CAP
var salary_cap_bonus := 0
var current_league := "SBL"
var unlocked_leagues: Array = ["SBL"]
var season_phase := "regular"
var championships: Dictionary = {}
var unlocked_offense: Array = ["快節奏轉換"]
var unlocked_defense: Array = ["人盯人"]
var card_inventory: Array = []
var veteran_cleared: Array = []
var coach_id := "sbl_rookie"
var coaches_owned: Array = ["sbl_rookie"]
var national_unlocked := false
var last_training_note := ""
var last_tactic_report := ""
var quarter_stories: Array = []
var match_threes: Array = [0, 0]
var combo_label := ""
var manga_look := true
var regular_wins := 0
var regular_losses := 0
var regular_games := 0
var iap_receipts: Dictionary = {}
var veteran_mission: Dictionary = {"origin": "", "games": 0, "wins": 0, "stage": 0}
var last_opponent: Dictionary = {}
var season_schedule: Array = []
var schedule_index := 0
var news_feed: Array = []
var web_news: Array = []
var news_http: HTTPRequest
var win_streak := 0
var last_box_sheet: Array = []
var last_match_gain: Dictionary = {}
var last_match_oncourt: Array = []
var last_home_points := 0
var league_table: Dictionary = {}
var swap_pick := -1
var roster_editing := false
var closer_name := ""
var last_known_unlocks: Array = []
var pending_path := ""
var iap_pending_sku := ""
var oauth_code_verifier := ""
var web_auth_consumed := false
var auth_redirect := AUTH_REDIRECT
var auth_listen_port := 8765
var analytics_session_sent := false
var analytics_install_id := ""
var analytics_install_pinged := false

var opponents := [
	{"name": "裕隆恐龍", "rating": 73, "city": "新北", "league": "SBL", "team_id": "sbl_yulon"},
	{"name": "台灣金控", "rating": 71, "city": "臺北", "league": "SBL", "team_id": "sbl_bank"},
	{"name": "台灣烈酒", "rating": 76, "city": "臺北", "league": "SBL", "team_id": "sbl_beer"},
	{"name": "彰化柏力力", "rating": 69, "city": "彰化", "league": "SBL", "team_id": "sbl_pure"},
]

var team_players: Array[Dictionary] = [
	{"name":"楊天佑", "pos":"PG", "ovr":78, "tier":"STAR", "color":"red", "image":"res://assets/players/player_1.png", "salary_million":160, "skill_id":"floor_general", "skill_name":"節奏大師", "skill_description":"提高團隊默契，降低比賽失誤波動"},
	{"name":"仲俊威", "pos":"SG", "ovr":76, "tier":"RARE", "color":"blue", "image":"res://assets/players/player_2.png", "salary_million":150, "skill_id":"three_and_d", "skill_name":"定點砲台", "skill_description":"空檔外線更穩定"},
	{"name":"王晟霖", "pos":"SF", "ovr":76, "tier":"RARE", "color":"blue", "image":"res://assets/players/player_3.png", "salary_million":150, "skill_id":"two_way_wing", "skill_name":"雙向側翼", "skill_description":"攻守兩端提供穩定加成"},
	{"name":"魏子雲", "pos":"PF", "ovr":72, "tier":"BASE", "color":"yellow", "image":"res://assets/players/player_4.png", "salary_million":120, "skill_id":"glass_cleaner", "skill_name":"禁區卡位", "skill_description":"籃板回合更穩定"},
	{"name":"周士淵", "pos":"C", "ovr":74, "tier":"BASE", "color":"yellow", "image":"res://assets/players/player_5.png", "salary_million":130, "skill_id":"screen_hub", "skill_name":"高位策應", "skill_description":"擋拆與二次進攻更有效"}
]

func _enter_tree() -> void:
	get_tree().node_added.connect(_queue_button_skin)
	get_tree().quit_on_go_back = false
	lock_editor_canvas()

func _queue_button_skin(node: Node) -> void:
	if is_handheld() and node is Control and is_ancestor_of(node):
		_prepare_touch_scroll.call_deferred(weakref(node))
	if node is Button and is_ancestor_of(node):
		_apply_button_skin.call_deferred(weakref(node))

func _prepare_touch_scroll(target: WeakRef) -> void:
	var control = target.get_ref()
	if not is_instance_valid(control) or not (control is Control) or not control.is_inside_tree():
		return
	# Sliders, scrollbars and editable text retain their own drag behavior.
	if control is Range or control is LineEdit or control is TextEdit:
		return
	var ancestor: Node = control.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor is ScrollContainer:
			# PASS lets the native touch scroller receive the emulated pointer gesture.
			# It then sends NOTIFICATION_SCROLL_BEGIN, cancelling pending button clicks.
			if control.mouse_filter == Control.MOUSE_FILTER_STOP:
				control.mouse_filter = Control.MOUSE_FILTER_PASS
			control.set_meta("touch_scroll_ready", true)
			return
		ancestor = ancestor.get_parent()

func _apply_button_skin(target: WeakRef) -> void:
	var button = target.get_ref()
	if is_instance_valid(button) and button is Button and button.is_inside_tree():
		ButtonSkin.apply(button)

func lock_editor_canvas() -> void:
	var game_window := get_window()
	game_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game_window.content_scale_size = Vector2i(960, 540) if is_handheld() else Vector2i(1280, 720)
	# Phones use a larger UI and expand the canvas to the device aspect ratio.
	game_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if is_handheld() else Window.CONTENT_SCALE_ASPECT_KEEP
	game_window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL

func _ready() -> void:
	lock_editor_canvas()
	load_tactic_rules()
	load_career_rules()
	load_league_teams()
	load_national_teams()
	load_jones_cup()
	load_extra_team_rosters()
	load_public_players()
	LocalProfiles.restore(self)
	load_account()
	apply_designer_unlocks()
	load_audio_settings()
	randomize()
	refresh_opponents()
	ensure_sfx()
	ensure_bgm()
	call_deferred("_kick_bgm")
	ensure_cloud()
	_ping_anonymous_install()
	restore_auth_session()
	start_auth_listener()
	load_cached_web_news()
	lock_editor_canvas()
	var game_window := get_window()
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var phone_preview := OS.get_environment("TB_FITSHOT") == "1" or OS.get_environment("TB_SCOUT") == "1"
		game_window.min_size = Vector2i(568, 320) if phone_preview else Vector2i(960, 540)
		game_window.size = Vector2i(1280, 720)
	game_window.title = "台籃模擬器"
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if is_logged_in():
		show_entering("正在回到球場…")
		pending_enter_after_auth = true
		apply_access_token(auth_access)
	else:
		show_login()
	call_deferred("_boot_watchdog")
	if OS.get_environment("TB_PLAYTEST") == "1":
		call_deferred("run_player_tour")
	if OS.get_environment("TB_MACPLAY") == "1":
		call_deferred("run_mac_play")

func _boot_watchdog() -> void:
	await get_tree().create_timer(1.0).timeout
	if OS.get_environment("TB_FITSHOT") == "1":
		call_deferred("run_iphone_fitshot")
		return
	if current_stage == 0 and pending_enter_after_auth:
		finish_auth_enter()
	if OS.get_environment("TB_SCOUT") == "1":
		pending_enter_after_auth = false
		welcome_open = false
		if not OS.has_feature("mobile"):
			get_window().size = Vector2i(844, 390)
		await get_tree().process_frame
		await get_tree().process_frame
		show_gacha_market()
		await get_tree().create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		var scout_shot := get_viewport().get_texture().get_image()
		if scout_shot != null:
			scout_shot.save_png("/tmp/godot_scout_iphone.png")
		get_tree().quit()
		return
	if OS.get_environment("TB_SHOT") == "1":
		welcome_open = false
		show_dashboard()
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		if shot != null:
			shot.save_png("/tmp/godot_hub.png")
		show_more_hub()
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var more_shot := get_viewport().get_texture().get_image()
		if more_shot != null:
			more_shot.save_png("/tmp/godot_more.png")
		show_roster()
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var roster_shot := get_viewport().get_texture().get_image()
		if roster_shot != null:
			roster_shot.save_png("/tmp/godot_roster.png")
		get_tree().quit()
	if OS.get_environment("TB_MATCH") == "1":
		pending_enter_after_auth = false
		welcome_open = false
		show_dashboard()
		await get_tree().create_timer(0.5).timeout
		show_match_prep()
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var prep_shot := get_viewport().get_texture().get_image()
		if prep_shot != null:
			prep_shot.save_png("/tmp/godot_prep.png")
		try_start_match()
		await get_tree().create_timer(2.2).timeout
		print("TB_MATCH_OK stage=", current_stage, " q=", reveal_quarter)
		await RenderingServer.frame_post_draw
		var match_shot := get_viewport().get_texture().get_image()
		if match_shot != null:
			match_shot.save_png("/tmp/godot_match.png")
		get_tree().quit()

func dump_playtest(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var folder := "playtest_mac" if OS.get_environment("TB_MACPLAY") == "1" else "playtest"
	image.save_png("/Users/yongye/Desktop/台灣籃球_Godot版/%s/%s.png" % [folder, tag])

func dump_fitshot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/Users/yongye/Desktop/台灣籃球_Godot版/playtest/iphone_land")
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("/Users/yongye/Desktop/台灣籃球_Godot版/playtest/iphone_land/%s.png" % tag)

func run_iphone_fitshot() -> void:
	pending_enter_after_auth = false
	welcome_open = false
	tutorial_seen = true
	var fit_size := Vector2i(844, 390)
	var requested_sizes := OS.get_environment("TB_TEST_SIZES").strip_edges()
	if not requested_sizes.is_empty():
		var first_size := requested_sizes.split(",")[0].strip_edges().to_lower()
		var dimensions := first_size.split("x")
		if dimensions.size() == 2 and dimensions[0].is_valid_int() and dimensions[1].is_valid_int():
			fit_size = Vector2i(maxi(320, int(dimensions[0])), maxi(240, int(dimensions[1])))
	if not OS.has_feature("mobile"):
		get_window().size = fit_size
	await get_tree().process_frame
	await get_tree().process_frame
	if team_players.is_empty():
		start_new_game()
		await get_tree().create_timer(0.45).timeout
		if not live_choices.is_empty():
			choose_live_player(0)
			await get_tree().create_timer(0.55).timeout
	show_dashboard()
	await get_tree().create_timer(0.55).timeout
	await dump_fitshot("01_hub_%dx%d" % [fit_size.x, fit_size.y])
	show_roster()
	await get_tree().create_timer(0.45).timeout
	await dump_fitshot("02_roster_%dx%d" % [fit_size.x, fit_size.y])
	show_gacha_market()
	await get_tree().create_timer(0.45).timeout
	await dump_fitshot("03_scout_%dx%d" % [fit_size.x, fit_size.y])
	show_store_hub()
	await get_tree().create_timer(0.45).timeout
	await dump_fitshot("04_store_%dx%d" % [fit_size.x, fit_size.y])
	match_rewards_pending = false
	last_match_played = true
	extra_match = false
	last_score = [86, 78]
	quarter_scores = [[22, 21, 22, 21], [19, 20, 20, 19]]
	quarter_stories = ["Q1 節奏穩", "Q2 外線開", "Q3 內線壓", "Q4 守住"]
	match_threes = [9, 7]
	last_home_points = 3
	last_tactic_report = "快節奏轉換"
	last_mvp = str(team_players[0].get("name", "MVP")) if not team_players.is_empty() else "MVP"
	last_opponent = current_match_opponent()
	if last_opponent.is_empty():
		last_opponent = {"name": "台灣金控"}
	show_post_match()
	await get_tree().create_timer(0.55).timeout
	await dump_fitshot("05_result_%dx%d" % [fit_size.x, fit_size.y])
	get_tree().quit()

func run_mac_play() -> void:
	await get_tree().create_timer(1.4).timeout
	if current_stage == 0 and not is_logged_in():
		await dump_playtest("mac_01_login")
		start_new_game()
		await get_tree().create_timer(0.45).timeout
		club_name = "台北烈焰俱樂部"
		show_live_selection()
		await get_tree().create_timer(0.45).timeout
		await dump_playtest("mac_02_stars")
		if not live_choices.is_empty():
			show_player_sheet(live_choices[0], func(): show_live_selection(), func(): choose_live_player(0), "選他當頭號球星")
			await get_tree().create_timer(0.5).timeout
			await dump_playtest("mac_03_star_card")
			choose_live_player(0)
			await get_tree().create_timer(0.7).timeout
	elif current_stage == 0 and is_logged_in():
		continue_after_login()
		await get_tree().create_timer(1.0).timeout
	await dump_playtest("mac_04_hub")
	show_roster()
	await get_tree().create_timer(0.5).timeout
	await dump_playtest("mac_05_roster")
	if not team_players.is_empty():
		show_player_sheet(team_players[0], func(): show_roster())
		await get_tree().create_timer(0.5).timeout
		await dump_playtest("mac_06_player_card")
	show_gacha_market()
	await get_tree().create_timer(0.45).timeout
	await dump_playtest("mac_07_scout")
	show_match_prep()
	await get_tree().create_timer(0.5).timeout
	await dump_playtest("mac_08_prep")
	if not over_salary_cap():
		start_match()
		await get_tree().create_timer(0.55).timeout
		await dump_playtest("mac_09_match_q0")
		if quarter_scores.size() >= 2 and quarter_scores[0] is Array and quarter_scores[1] is Array and quarter_scores[0].size() >= 1 and quarter_scores[1].size() >= 1:
			reveal_quarter = 1
			last_score = [int(quarter_scores[0][0]), int(quarter_scores[1][0])]
			show_match_presentation()
			await get_tree().create_timer(0.55).timeout
			await dump_playtest("mac_10_match_q1")
		reveal_quarter = 4
		last_score = [0, 0]
		if quarter_scores.size() >= 2 and quarter_scores[0] is Array and quarter_scores[1] is Array:
			for i in mini(4, mini(quarter_scores[0].size(), quarter_scores[1].size())):
				last_score[0] += int(quarter_scores[0][i])
				last_score[1] += int(quarter_scores[1][i])
		show_match_presentation()
		await get_tree().create_timer(0.55).timeout
		await dump_playtest("mac_11_match_end")
		show_post_match()
		await get_tree().create_timer(0.55).timeout
		await dump_playtest("mac_12_result")
	show_dashboard()
	await get_tree().create_timer(0.4).timeout
	await dump_playtest("mac_13_hub_after")

func run_player_tour() -> void:
	await get_tree().create_timer(0.45).timeout
	await dump_playtest("tour_01_login")
	for spec in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1920, 886)]:
		get_window().size = spec
		await get_tree().process_frame
		await get_tree().process_frame
		show_login()
		await get_tree().create_timer(0.2).timeout
		await dump_playtest("tour_01_login_%dx%d" % [spec.x, spec.y])
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	show_login()
	start_new_game()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_02_build")
	club_name = "台北烈焰俱樂部"
	show_live_selection()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_03_live")
	if not live_choices.is_empty():
		choose_live_player(0)
	await get_tree().create_timer(0.6).timeout
	await dump_playtest("tour_04_hub")
	show_roster()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_05_roster")
	show_market()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_14_market")
	show_more_hub()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_15_more")
	show_game_guide()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_16_guide")
	show_dashboard()
	await get_tree().create_timer(0.45).timeout
	await dump_playtest("tour_04b_hub")
	show_league_overview()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_11_league")
	show_trade_market()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_12_trade")
	show_gacha_market()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_06_collection")
	show_match_prep()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_07_prep")
	start_match()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_08_match_q0")
	if quarter_scores.size() >= 2 and quarter_scores[0] is Array and quarter_scores[1] is Array and quarter_scores[0].size() >= 1 and quarter_scores[1].size() >= 1:
		reveal_quarter = 1
		last_score = [int(quarter_scores[0][0]), int(quarter_scores[1][0])]
		show_match_presentation()
		await get_tree().create_timer(0.35).timeout
		await dump_playtest("tour_08b_cutin")
	reveal_quarter = 4
	last_score = [0, 0]
	if quarter_scores.size() >= 2 and quarter_scores[0] is Array and quarter_scores[1] is Array:
		for i in mini(4, mini(quarter_scores[0].size(), quarter_scores[1].size())):
			last_score[0] += int(quarter_scores[0][i])
			last_score[1] += int(quarter_scores[1][i])
	show_match_presentation()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_09_match_end")
	show_post_match()
	await get_tree().create_timer(0.35).timeout
	await dump_playtest("tour_10_result")
	for _g in 9:
		show_match_prep()
		start_match()
		skip_match_presentation()
		await get_tree().process_frame
	await dump_playtest("tour_13_season")
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back_request()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if current_stage >= 3:
			save_game()
			flush_cloud_save(true)
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_handheld():
			set_app_suspended(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_handheld():
			set_app_suspended(false)

func set_app_suspended(suspended: bool) -> void:
	# Desktop preview windows can emit a focus notification while the root node is
	# still entering/leaving the tree. Mobile lifecycle calls must be harmless too.
	if not is_inside_tree():
		return
	if _app_suspended == suspended:
		return
	_app_suspended = suspended
	if suspended:
		match_play_id += 1
		_foreground_fps = Engine.max_fps
		Engine.max_fps = 10
		if current_stage >= 3:
			save_game()
			flush_cloud_save(true)
		_resume_tree = not get_tree().paused
		get_tree().paused = true
	else:
		Engine.max_fps = _foreground_fps
		if _resume_tree:
			get_tree().paused = false
		if current_stage == 6 and match_rewards_pending and not match_defense_menu:
			run_match_autoplay(match_play_id)
	if is_instance_valid(bgm_player):
		bgm_player.stream_paused = suspended
	if is_instance_valid(sfx_player):
		sfx_player.stream_paused = suspended

func handle_back_request() -> void:
	if is_instance_valid(share_modal):
		close_share_sheet()
	elif is_instance_valid(card_reveal_modal):
		close_card_reveal()
	elif is_instance_valid(trade_modal):
		close_trade_modal()
	elif is_instance_valid(training_modal):
		close_training_modal()
	elif is_instance_valid(guide_modal):
		close_guide_modal()
	elif current_stage == 6 and match_rewards_pending:
		flash_notice("比賽進行中，可按「略過」完成本場並領取結算。")
	elif current_stage != 0 and active_menu != "dashboard":
		go_return_page()

func load_tactic_rules() -> void:
	tactic_rules.clear()
	if not FileAccess.file_exists(TACTIC_RULES_PATH):
		return
	var file := FileAccess.open(TACTIC_RULES_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		tactic_rules = parsed

func load_career_rules() -> void:
	career_rules = {}
	if not FileAccess.file_exists(CAREER_PATH):
		return
	var file := FileAccess.open(CAREER_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		career_rules = parsed
	apply_salary_cap()

func disclaimer_line() -> String:
	return str(career_rules.get("disclaimer", "非官方體育模擬器，無聯盟或球隊官方授權；能力與薪資為遊戲設定。"))

func show_legal_notice() -> void:
	show_guide_sheet(LEGAL_NOTICE_TITLE, LEGAL_NOTICE_TEXT, CYAN)

func legal_notice_button() -> Button:
	var button := action_button(LEGAL_NOTICE_TITLE, Color("254052"), show_legal_notice, Vector2(0, 44))
	button.name = "LegalNoticeButton"
	return button

func regular_season_length() -> int:
	if current_league in ["EASL", "BCL"]:
		return 3
	return maxi(12, int(career_rules.get("regular_games", 20)))

func playoff_wins_needed() -> int:
	return maxi(6, int(round(float(regular_season_length()) * 0.5)))

func slot_save_path(slot: int) -> String:
	return LocalProfiles.path_for(local_profile_id,"taiwan_basketball_save_%d.json" % slot)

func account_save_path() -> String:
	return LocalProfiles.path_for(local_profile_id,"taiwan_basketball_account.json")

func legacy_save_path() -> String:
	return LocalProfiles.path_for(local_profile_id,"taiwan_basketball_save.json")

func parse_save_dict(raw_text: String) -> Dictionary:
	var text := raw_text.strip_edges()
	if text.length() < 2 or not text.begins_with("{") or not text.ends_with("}"):
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

func max_save_slots() -> int:
	var n := 2 + extra_save_bought
	if referral_slot_granted:
		n += 1
	return clampi(n, 2, 10)

func extra_slots_left() -> int:
	return maxi(0, 10 - max_save_slots())

func load_account() -> void:
	var parsed := SaveStore.read_save(account_save_path())
	if not parsed.is_empty():
		extra_save_unlocked = bool(parsed.get("extra_save_unlocked", false))
		extra_save_bought = int(parsed.get("extra_save_bought", 0))
		referral_code = str(parsed.get("referral_code", ""))
		referral_entered = str(parsed.get("referral_entered", ""))
		referral_count = int(parsed.get("referral_count", 0))
		referral_slot_granted = bool(parsed.get("referral_slot_granted", false))
		lin_hidden_granted = bool(parsed.get("lin_hidden_granted", false))
		active_save_slot = int(parsed.get("last_slot", 0))
		if parsed.has("iap_receipts") and parsed.iap_receipts is Dictionary:
			iap_receipts = parsed.iap_receipts.duplicate(true)
		if bool(iap_receipts.get("extra_save", false)):
			extra_save_unlocked = true
			extra_save_bought = maxi(extra_save_bought, 1)
		extra_save_bought = maxi(extra_save_bought, int(iap_receipts.get("extra_save_count", 0)))
		if bool(iap_receipts.get("easl", false)) or bool(parsed.get("easl_pass", false)):
			easl_pass = true
		if bool(iap_receipts.get("jones", false)) or bool(parsed.get("jones_pass", false)):
			jones_pass = true
	if FileAccess.file_exists(legacy_save_path()) and not FileAccess.file_exists(slot_save_path(0)):
		var old := FileAccess.open(legacy_save_path(), FileAccess.READ)
		if old:
			var copy := FileAccess.open(slot_save_path(0), FileAccess.WRITE)
			if copy:
				copy.store_string(old.get_as_text())

func save_account() -> void:
	write_account_disk()
	_cloud_account_dirty = true
	_cloud_idle = 0.0
	if current_stage < 3:
		flush_cloud_save(true)

func write_account_disk() -> void:
	var slots: Array = []
	for i in max_save_slots():
		var path := slot_save_path(i)
		var row := {"slot": i, "empty": true, "club": "空檔", "line": "尚未開打"}
		if FileAccess.file_exists(path):
			var slot_file := FileAccess.open(path, FileAccess.READ)
			if slot_file:
				var raw_text := slot_file.get_as_text().strip_edges()
				slot_file.close()
				var parsed := parse_save_dict(raw_text)
				if not parsed.is_empty():
					row["empty"] = false
					row["club"] = str(parsed.get("club_name", "俱樂部"))
					row["line"] = "%s · %d-%d" % [parsed.get("current_league", "SBL"), int(parsed.get("season_wins", 0)), int(parsed.get("season_losses", 0))]
		slots.append(row)
	var error := SaveStore.write_save(account_save_path(), {
			"extra_save_unlocked": extra_save_unlocked or extra_save_bought > 0,
			"extra_save_bought": extra_save_bought,
			"referral_code": ensure_referral_code(),
			"referral_entered": referral_entered,
			"referral_count": referral_count,
			"referral_slot_granted": referral_slot_granted,
			"lin_hidden_granted": lin_hidden_granted,
			"easl_pass": easl_pass,
			"jones_pass": jones_pass,
			"last_slot": active_save_slot,
			"slots": slots,
			"iap_receipts": iap_receipts,
		})
	if error != OK:
		push_warning("Account metadata save failed (%d)." % error)

func tick_cloud_autosave(delta: float) -> void:
	if current_stage < 3 or not is_logged_in():
		return
	if not _cloud_dirty and not _cloud_account_dirty:
		_cloud_idle = 0.0
		_cloud_held = 0.0
		return
	_cloud_idle += delta
	_cloud_held += delta
	var rush := current_stage == 6 and _cloud_idle >= 1.2
	if rush or _cloud_idle >= 2.8 or _cloud_held >= 18.0:
		flush_cloud_save(false)

func flush_cloud_save(force := false) -> void:
	if cloud_restore_incomplete:
		return # Never upload local defaults over a save we have not read yet.
	if not is_logged_in() or auth_user_id.is_empty():
		_cloud_dirty = false
		_cloud_account_dirty = false
		return
	if not force and cloud_is_busy():
		return
	save_extra_run()
	var data := collect_save_data()
	if _cloud_dirty or force:
		if cloud_push(data):
			_cloud_dirty = false
	if _cloud_account_dirty or force:
		cloud_push_account()
		_cloud_account_dirty = false
	_cloud_idle = 0.0
	_cloud_held = 0.0

func save_game() -> void:
	if _settling_match:
		return # Reward helpers must not persist a half-applied transaction.
	save_extra_run()
	var data := collect_save_data()
	var error := SaveStore.write_save(slot_save_path(active_save_slot), data)
	if error != OK:
		push_error("Local save failed (%d); previous save preserved." % error)
		if not _save_failed_notice:
			_save_failed_notice = true
			flash_notice("存檔失敗，請確認手機剩餘空間；先不要關閉遊戲。")
		return
	_save_failed_notice = false
	# Keep the old path readable for older builds; the slot is authoritative.
	if SaveStore.write_save(legacy_save_path(), data) != OK:
		push_warning("Legacy save mirror could not be updated.")
	write_account_disk()
	_cloud_dirty = true
	_cloud_account_dirty = true
	_cloud_idle = 0.0
	if current_stage < 3:
		flush_cloud_save(true)

func refresh_opponents(reshuffle := false) -> void:
	opponents.clear()
	var want := current_league
	for team in league_teams:
		var lg := str(team.get("league", ""))
		var ok := false
		if want == "SBL":
			ok = lg == "SBL"
		elif want == "PLG":
			ok = lg == "PLG"
		elif want == "TPBL":
			ok = lg == "TPBL"
		elif want == "EASL" or want == "BCL":
			ok = lg == "PLG" or lg == "TPBL"
		if ok:
			var rival := official_rival(team)
			if want == "EASL":
				rival["name"] = "東超·%s" % rival.get("name", "對手")
			elif want == "BCL":
				rival["name"] = "BCL·%s" % rival.get("name", "對手")
			opponents.append(rival)
	if opponents.is_empty():
		opponents = [{"name": "彰化柏力力", "rating": 72, "city": "彰化", "team_id": "sbl_pure", "league": "SBL"}]
	opponents.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("rating", 70)) > int(b.get("rating", 70)))
	if reshuffle:
		build_season_schedule()
		reset_league_table()
	else:
		if season_schedule.is_empty() and season_phase == "regular":
			build_season_schedule()
		else:
			apply_current_fixture()
		if league_table.is_empty():
			reset_league_table()

func ranked_opponents() -> Array:
	if opponents.is_empty():
		refresh_opponents()
	return opponents

func current_match_opponent() -> Dictionary:
	if extra_match or (not prep_extra_event.is_empty() and prep_extra_event == extra_event):
		var extra := extra_match_opponent()
		if not extra.is_empty():
			return apply_opponent_ovr_bonus(extra)
	return apply_opponent_ovr_bonus(league_match_opponent())

func apply_opponent_ovr_bonus(raw: Dictionary) -> Dictionary:
	# 目前場次可能會被多個畫面讀取；標記可避免同一份對手複本重複加成。
	var rival := raw.duplicate(true)
	if bool(rival.get("_opponent_ovr_bonus_applied", false)):
		return rival
	rival["_opponent_ovr_bonus_applied"] = true
	rival["rating"] = clampi(int(rival.get("rating", 70)) + OPPONENT_OVR_BONUS, 50, 99)
	var players = rival.get("players", [])
	if players is Array:
		var boosted: Array = []
		for item in players:
			if item is Dictionary:
				var player: Dictionary = item.duplicate(true)
				player["ovr"] = clampi(int(player.get("ovr", 70)) + OPPONENT_OVR_BONUS, 1, 99)
				boosted.append(player)
			else:
				boosted.append(item)
		rival["players"] = boosted
	return rival

func extra_match_opponent() -> Dictionary:
	if extra_queue.is_empty():
		return {}
	var raw = extra_queue[0]
	if raw is Dictionary:
		return extra_rival_from(raw)
	return {}

func extra_rival_from(raw: Dictionary) -> Dictionary:
	var tid := str(raw.get("id", raw.get("team_id", "")))
	var roster: Array = raw.get("players", [])
	if roster.is_empty():
		roster = extra_team_players(tid)
	return {
		"name": fictional_team_name(tid, str(raw.get("name", "對手"))),
		"rating": int(raw.get("rating", 78)),
		"city": str(raw.get("city", "")),
		"league": str(extra_event_data(extra_event).get("title", "額外比賽")),
		"team_id": tid,
		"id": tid,
		"extra": true,
		"players": roster,
		"source": str(raw.get("source", extra_team_rosters.get(tid, {}).get("source", ""))),
	}

func league_match_opponent() -> Dictionary:
	var series := PlayoffSeries.user_series(playoff_state)
	if season_phase in ["playin", "semifinal", "final"] and not series.is_empty():
		var mine_high := str(series.a.team_id) == club_team_id()
		is_home_game = not bool(series.neutral) and (PlayoffSeries.high_home(series) == mine_high)
		return (series.b if mine_high else series.a).duplicate(true)
	var pool := ranked_opponents()
	if pool.is_empty():
		return {"name": "對手", "rating": 72, "team_id": ""}
	if season_phase == "final" or season_phase == "champion":
		return playoff_seed_team(0)
	if season_phase == "semifinal":
		return playoff_seed_team(3 if club_seed() <= 2 else 0)
	if season_phase == "regular" and schedule_index >= 0 and schedule_index < season_schedule.size():
		var raw_game = season_schedule[schedule_index]
		if raw_game is Dictionary:
			var game: Dictionary = raw_game
			is_home_game = bool(game.get("home", true))
			var team = game.get("team", {})
			if team is Dictionary and not team.is_empty():
				return team
	if pool.is_empty():
		return {"name": "對手", "rating": 72, "team_id": ""}
	return pool[opponent_index % pool.size()]

func draw_next_matchup(avoid_repeat := true) -> void:
	var pool := ranked_opponents()
	if pool.is_empty():
		return
	if season_phase != "regular":
		is_home_game = randi() % 2 == 0
		return
	var last_id := str(last_opponent.get("team_id", ""))
	var choices: Array[int] = []
	for i in pool.size():
		var team: Dictionary = pool[i]
		if avoid_repeat and pool.size() > 1 and str(team.get("team_id", "")) == last_id:
			continue
		choices.append(i)
	if choices.is_empty():
		for i in pool.size():
			choices.append(i)
	opponent_index = choices[randi() % choices.size()]
	is_home_game = randi() % 2 == 0

func home_court_bonus() -> int:
	if not extra_match and current_league == "SBL" and season_phase in ["semifinal", "final"]:
		return 0
	return 2 if is_home_game else 0

func home_court_line() -> String:
	if not extra_match and current_league == "SBL" and season_phase in ["semifinal", "final"]:
		return "集中場地 · 無主場加成"
	if is_home_game:
		return "主場加成 戰力 +%d" % home_court_bonus()
	return "客場作戰 無主場加成"

func club_team_id() -> String:
	return "club"

func over_salary_cap() -> bool:
	return roster_salary() > salary_cap

func minimum_roster_to_play() -> int:
	return 7

func roster_depth_penalty_percent() -> int:
	var count := team_players.size()
	if count >= gameday_limit():
		return 0
	if count <= minimum_roster_to_play():
		return 10
	# 人越多，輪替越完整；8 人起每多 1 人少 2 個百分點。
	return (gameday_limit() - count) * 2

func roster_availability_line() -> String:
	var count := team_players.size()
	if count < minimum_roster_to_play():
		return "目前 %d 人 · 至少 7 人才能開打" % count
	return "目前 %d 人 · 可開打 · %s" % [count, "輪替完整" if count >= gameday_limit() else "補齊 12 人可減少輪替劣勢"]

func league_salary_floor() -> int:
	var league := current_league
	if league in ["EASL", "BCL"]:
		league = last_pro_league if last_pro_league in ["SBL", "PLG", "TPBL"] else "PLG"
	if league in ["PLG", "TPBL"]:
		return SALARY_CAP_PRO
	return SALARY_CAP_SBL

func apply_salary_cap() -> void:
	salary_cap = league_salary_floor() + maxi(0, salary_cap_bonus)
	# 舊存檔曾把 SBL 帽寫成 6000。沒有贏來的 bonus 就回到現在的地板。
	if current_league == "SBL" and salary_cap_bonus <= 0:
		salary_cap = SALARY_CAP_SBL

func win_streak_rate() -> float:
	if win_streak >= 10:
		return 0.30
	if win_streak >= 5:
		return 0.20
	if win_streak >= 3:
		return 0.10
	return 0.0

func apply_win_streak(value: int) -> int:
	return int(round(float(value) * (1.0 + win_streak_rate())))

func ensure_season_scout() -> void:
	if scout_points >= 1:
		return
	if scout_floor_game == season_games:
		return
	scout_points = 1
	scout_floor_game = season_games

func is_foreigner(player: Dictionary) -> bool:
	return str(player.get("identity", "local")) == "foreign"

func is_foreign_student(player: Dictionary) -> bool:
	return str(player.get("identity", "local")) == "foreign_student"

func identity_label(player: Dictionary) -> String:
	if is_veteran_player(player):
		return "黃金世代老將"
	match str(player.get("identity", "local")):
		"foreign":
			return "外援"
		"foreign_student":
			return "外籍生"
		_:
			return "本土"

func identity_accent(player: Dictionary) -> Color:
	if is_veteran_player(player):
		return GOLD
	match str(player.get("identity", "local")):
		"foreign":
			return ORANGE
		"foreign_student":
			return PURPLE
		_:
			return CYAN

func normalize_pos_code(raw: String) -> String:
	var t := raw.strip_edges().to_upper()
	match t:
		"控衛", "控球後衛", "控球", "G", "GUARD":
			return "PG"
		"得分後衛", "SG":
			return "SG"
		"小前鋒", "小前", "F", "FORWARD":
			return "SF"
		"大前鋒", "大前":
			return "PF"
		"中鋒":
			return "C"
		"CENTER":
			return "C"
		"PG", "SF", "PF", "C":
			return t
		_:
			return t if t.length() <= 3 else ""

func canonical_position_text(raw: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var normalized_raw := raw.to_upper().replace("／", "/").replace("-", "/").replace("、", "/")
	for piece in normalized_raw.split("/"):
		var code := normalize_pos_code(piece)
		if not code.is_empty() and not parts.has(code):
			parts.append(code)
	return "/".join(parts)

func infer_swing_pos(_player: Dictionary, _primary: String) -> String:
	return ""

func listed_position_from_data(player: Dictionary) -> String:
	var who := str(player.get("name", ""))
	if who.is_empty():
		return ""
	# Curated golden-generation profiles are authoritative.  Public roster
	# imports can contain an outdated single-position label and must not
	# overwrite a corrected veteran position later in the conversion pipeline.
	var veteran_profile := golden_generation_profile(player)
	if not veteran_profile.is_empty():
		var curated := canonical_position_text(str(veteran_profile.get("position", veteran_profile.get("pos", ""))))
		if not curated.is_empty():
			return curated
	for raw in public_players:
		if str(raw.get("name", "")) == who:
			var listed := canonical_position_text(str(raw.get("position", raw.get("pos", ""))))
			if not listed.is_empty():
				return listed
	for team in league_teams:
		for raw in team.get("players", []):
			if raw is Dictionary and str(raw.get("name", "")) == who:
				var listed2 := canonical_position_text(str(raw.get("position", raw.get("pos", ""))))
				if not listed2.is_empty():
					return listed2
	return ""

func position_data_missing(player: Dictionary) -> bool:
	var profile := golden_generation_profile(player)
	if profile.is_empty():
		return false
	# Validate the source card before any veteran-profile migration fills the
	# curated position.  This keeps incomplete imports visible to the audit/UI
	# while cards created through to_game_player still use the corrected profile.
	var source_position := str(player.get("position", player.get("pos", ""))).strip_edges()
	return source_position.is_empty()

func player_pos_list(player: Dictionary) -> PackedStringArray:
	var who := str(player.get("name", ""))
	if NATURAL_DUAL.has(who):
		var dual: PackedStringArray = PackedStringArray()
		for piece in NATURAL_DUAL[who]:
			var code := normalize_pos_code(str(piece))
			if not code.is_empty() and not dual.has(code):
				dual.append(code)
		if not dual.is_empty():
			return dual if bool(player.get("secondary_position_unlocked", false)) else PackedStringArray([dual[0]])
	var listed := listed_position_from_data(player)
	var raw := listed if not listed.is_empty() else str(player.get("pos", player.get("position", "")))
	raw = raw.to_upper().replace("／", "/").replace("-", "/").replace("、", "/")
	var parts: PackedStringArray = PackedStringArray()
	for piece in raw.split("/"):
		var t := normalize_pos_code(piece)
		if not t.is_empty() and not parts.has(t):
			parts.append(t)
	if parts.is_empty():
		parts.append("SG")
	if parts.size() > 1 and not bool(player.get("secondary_position_unlocked", false)):
		return PackedStringArray([parts[0]])
	return parts

func player_all_positions(player: Dictionary) -> PackedStringArray:
	var who := str(player.get("name", ""))
	if NATURAL_DUAL.has(who):
		return PackedStringArray(NATURAL_DUAL[who])
	var listed := listed_position_from_data(player)
	var raw := listed if not listed.is_empty() else str(player.get("pos", player.get("position", "")))
	return canonical_position_text(raw).split("/") if not canonical_position_text(raw).is_empty() else PackedStringArray(["SG"])

func has_secondary_position(player: Dictionary) -> bool:
	return player_all_positions(player).size() >= 2

func unlock_secondary_position(index: int) -> void:
	if index < 0 or index >= team_players.size():
		return
	var player: Dictionary = team_players[index]
	if not has_secondary_position(player):
		flash_notice("這張卡沒有第二位置。")
		return
	if int(player.get("training_sessions", 0)) < TRAINING_MAX_SESSIONS:
		flash_notice("必須先完成特訓 +5 才能解鎖副位置。")
		return
	if bool(player.get("secondary_position_unlocked", false)):
		flash_notice("副位置已經解鎖。")
		return
	player["secondary_position_unlocked"] = true
	team_players[index] = player
	save_game()
	flash_notice("%s 已解鎖副位置：%s。" % [player.get("name", "球員"), player_all_positions(player)[1]])
	show_owned_player(index)

func player_has_frontcourt(player: Dictionary) -> bool:
	for pos in player_pos_list(player):
		if pos in ["PF", "C"]:
			return true
	return false

func player_is_sf(player: Dictionary) -> bool:
	return player_pos_list(player).has("SF")

func player_can_play_frontcourt(player: Dictionary) -> bool:
	return player_has_frontcourt(player) or player_is_sf(player)

func player_has_backcourt(player: Dictionary) -> bool:
	for pos in player_pos_list(player):
		if pos in ["PG", "SG", "SF"]:
			return true
	return false

func starter_court_side(index: int) -> String:
	if index < 0 or index >= 5:
		return ""
	return "front" if index >= 3 else "back"

func player_fits_slot(player: Dictionary, slot: String) -> bool:
	if slot.is_empty():
		return true
	if slot == "BACK":
		return player_has_backcourt(player)
	if slot == "FRONT":
		return player_can_play_frontcourt(player)
	return player_pos_list(player).has(slot)

func starter_slot(index: int) -> String:
	if index >= 0 and index < STARTER_SLOTS.size():
		return str(STARTER_SLOTS[index])
	return ""

func slot_fit_penalty(player: Dictionary, index: int) -> int:
	var slot := starter_slot(index)
	if slot.is_empty():
		return 0
	return 0 if player_pos_list(player).has(slot) else 5

func lineup_wrong_side() -> bool:
	return false

func lineup_sf_front() -> bool:
	if lineup_wrong_side():
		return false
	for i in mini(team_players.size(), 5):
		if slot_fit_penalty(team_players[i], i) == 5:
			return true
	return false

func position_mismatch_penalty(player: Dictionary, index: int) -> int:
	if index < 0 or index >= 5:
		return 0
	return slot_fit_penalty(player, index)

func roster_aura_ovr() -> int:
	for i in mini(team_players.size(), gameday_limit()):
		if str(team_players[i].get("skill_id", "")) == "team_ovr_aura":
			return 1
	return 0

func effective_ovr(player: Dictionary, index := -1) -> int:
	var ovr := int(player.get("ovr", 70)) + roster_aura_ovr()
	return maxi(50, ovr - position_mismatch_penalty(player, index))

func lineup_mismatch_count() -> int:
	if lineup_wrong_side():
		return mini(team_players.size(), 5)
	var n := 0
	for i in mini(team_players.size(), 5):
		if slot_fit_penalty(team_players[i], i) > 0:
			n += 1
	return n

func lineup_mismatch_line() -> String:
	if lineup_wrong_side():
		return "先發位置不符，該位 -5 OVR"
	if lineup_sf_front():
		return "先發位置不符，該位 -5 OVR"
	return ""

func lineup_mismatch_short() -> String:
	if lineup_wrong_side():
		return "位置不符\n該位 -5"
	if lineup_sf_front():
		return "位置不符\n該位 -5"
	return ""

func lineup_side_hint() -> Control:
	var miss := lineup_mismatch_short()
	if miss.is_empty():
		var empty := Control.new()
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return empty
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(72, 50)
	shell.size_flags_horizontal = Control.SIZE_SHRINK_END
	shell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_theme_stylebox_override("panel", panel_style(RED.darkened(0.72), RED.darkened(0.15), 10, 1))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	shell.add_child(padded(box, 6))
	box.add_child(plain_label("陣容", 11, RED, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(plain_label(miss, 11, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	return shell

func position_mark(player: Dictionary) -> String:
	var parts := player_all_positions(player)
	if parts.size() >= 2 and bool(player.get("secondary_position_unlocked", false)):
		return "雙能 %s／%s" % [parts[0], parts[1]]
	if parts.size() >= 2:
		return "%s／%s 🔒" % [parts[0], parts[1]]
	return parts[0]

func pos_chip(player: Dictionary, compact := false) -> Control:
	var dual := player_all_positions(player).size() >= 2
	var accent := ORANGE if dual else GOLD
	var mark := position_mark(player)
	if compact:
		var parts := player_pos_list(player)
		if parts.size() >= 2:
			mark = "%s／%s" % [parts[0], parts[1]]
		else:
			mark = parts[0]
	return card_stat_chip(mark, accent, compact)

func identity_chip(player: Dictionary, compact := false) -> Control:
	if is_foreign_student(player):
		return card_stat_chip("外籍生", PURPLE, compact)
	if is_foreigner(player):
		return card_stat_chip("外援", ORANGE, compact)
	var blank := Control.new()
	blank.visible = false
	blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return blank

func ovr_chip(player: Dictionary, index := -1, compact := false) -> Control:
	var shown := effective_ovr(player, index)
	var miss := position_mismatch_penalty(player, index) > 0
	var accent := RED if miss else player_frame_color(player)
	return card_stat_chip(str(shown), accent, compact)

func card_stat_chip(text_value: String, accent: Color, compact := false) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.02, 0.92)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6 if compact else 8)
	style.content_margin_left = 3 if compact else 5
	style.content_margin_right = 3 if compact else 5
	style.content_margin_top = 1 if compact else 2
	style.content_margin_bottom = 1 if compact else 2
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	var lab := plain_label(text_value, 10 if compact else 12, accent, true, HORIZONTAL_ALIGNMENT_CENTER)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lab.custom_minimum_size = Vector2(0, 13 if compact else 16)
	panel.add_child(lab)
	return panel

func combo_help_note(player: Dictionary) -> String:
	if is_combo_wild(player):
		return "鑽石卡 · 免費算進任何隊伍組合" if player_tier_key(player) == "diamond" else "隱藏卡 · 算進任何組合"
	if is_veteran_player(player):
		return "黃金世代 · 算進任何組合"
	if bool(player.get("combo_flex_paid", false)):
		return "彈性組合 · %s" % combo_origin_label(str(player.get("combo_flex_origin", "")))
	var origin := origin_id(player)
	if origin.is_empty():
		return ""
	var st := combo_progress_state()
	var current := str(st.get("origin", ""))
	var n := int(st.get("count", 0))
	var short := team_short_name(origin)
	if not current.is_empty() and origin == current and n > 0:
		return "%s · 組合同隊 +1" % short
	return short

func foreigner_count() -> int:
	var n := 0
	for player in team_players:
		if is_foreigner(player):
			n += 1
	return n

func foreign_student_count() -> int:
	var n := 0
	for player in team_players:
		if is_foreign_student(player):
			n += 1
	return n

func foreigner_limit() -> int:
	match current_league:
		"SBL":
			return 1
		"PLG":
			return 3
		"TPBL":
			return 4
		"EASL", "BCL":
			return 4
		_:
			return 2

func foreigner_oncourt_limit() -> int:
	match current_league:
		"SBL":
			return 1
		"PLG", "TPBL":
			return 2
		"EASL", "BCL":
			return 2
		_:
			return 2

func foreign_student_limit() -> int:
	match current_league:
		"SBL":
			return 2
		_:
			return 2

func foreigner_rule_line() -> String:
	match current_league:
		"SBL":
			return "SBL 單洋將：註冊最多 1 名外援"
		"PLG":
			return "PLG：註冊最多 3 名外援"
		"TPBL":
			return "TPBL：註冊 4 名外援，場上最多 2 人"
		"EASL", "BCL":
			return "國際賽：外援比照職業聯盟上限"
		_:
			return "外援依聯盟規章"

func foreign_student_rule_line() -> String:
	return "外籍生是額外類別，不佔外援名額。最多 %d 人" % foreign_student_limit()

func foreigner_detail_line() -> String:
	var now := "%d／%d" % [foreigner_count(), foreigner_limit()]
	match current_league:
		"SBL":
			return "SBL 是單洋將制：名單只能有 1 名外援，不能再簽第二人。現在 %s。外援年薪較高，球探點也比較貴。" % now
		"PLG":
			return "PLG：名單最多 3 名外援。超過上限就不能再挖、不能再買。現在 %s。外援年薪較高，球探點也比較貴。" % now
		"TPBL":
			return "TPBL：名單可註冊 4 名外援，但上場同時最多 2 人。現在 %s。外援年薪較高，球探點也比較貴。" % now
		"EASL", "BCL":
			return "國際賽外援上限比照職業聯盟。現在 %s。" % now
		_:
			return "外援有人數上限。現在 %s。外援年薪較高，球探點也比較貴。" % now

func foreign_student_detail_line() -> String:
	return "外籍生是額外類別：打過 UBA 的外籍學生，不算單洋將。現在 %d／%d。" % [foreign_student_count(), foreign_student_limit()]

func scout_point_cost(player: Dictionary) -> int:
	var salary := published_salary(player)
	if salary >= 2000:
		return 5
	if salary >= 800:
		return 4
	if salary >= 400:
		return 3
	if salary >= 220:
		return 2
	return 1

func roster_limit() -> int:
	return 12

func gameday_limit() -> int:
	return 12

func push_news(line: String) -> void:
	if line.is_empty():
		return
	news_feed.insert(0, {"title": season_phase_label(), "body": line})
	if news_feed.size() > 16:
		news_feed.resize(16)
	last_news = line

func fixture_label() -> String:
	if not extra_match and season_phase in ["playin", "semifinal", "final"] and not playoff_state.is_empty():
		return playoff_series_line() + " · " + ("集中場地" if current_league == "SBL" else ("主場" if is_home_game else "客場"))
	if extra_match:
		var data := extra_event_data(extra_event)
		var need := int(data.get("need", 3))
		return "%s · 第 %d／%d 場" % [str(data.get("title", "額外比賽")), extra_wins + 1, need]
	if season_phase == "offseason":
		return "休賽季"
	if season_phase == "champion":
		return "衛冕"
	var total := regular_season_length()
	var n := mini(schedule_index + 1, total)
	var venue := "主場" if is_home_game else "客場"
	var weekend := false
	if schedule_index >= 0 and schedule_index < season_schedule.size():
		weekend = bool(season_schedule[schedule_index].get("weekend", false))
	if weekend and is_home_game:
		venue = "主場焦點"
	if current_league in ["EASL", "BCL"]:
		return "國際賽 %d／%d · %s" % [n, total, venue]
	if season_phase == "semifinal":
		return "四強 · %s" % venue
	if season_phase == "final":
		return "冠軍戰 · %s（戰績較佳主場）" % venue
	return "第 %d／%d 場 · %s" % [n, total, venue]

func next_fixture_line() -> String:
	if season_phase in ["playin", "semifinal", "final"] and not playoff_state.is_empty():
		return playoff_series_line()
	var nxt := schedule_index + 1
	if nxt >= 0 and nxt < season_schedule.size():
		var game: Dictionary = season_schedule[nxt]
		var team: Dictionary = game.get("team", {})
		var venue := "主場" if bool(game.get("home", true)) else "客場"
		return "再下一場 %s vs %s" % [venue, team.get("name", "對手")]
	if season_phase == "offseason":
		return "休賽季：選下一季或換聯盟"
	if season_phase == "regular":
		return "例行賽倒數"
	return "準備季後賽"

func build_season_schedule() -> void:
	season_schedule.clear()
	schedule_index = 0
	var pool := ranked_opponents()
	if pool.is_empty():
		return
	var need := regular_season_length()
	var bag: Array = []
	var cursor := 0
	while bag.size() < need:
		var team: Dictionary = pool[cursor % pool.size()]
		var round_n := int(float(bag.size()) / float(pool.size()))
		var home := round_n % 2 == 0
		if round_n % 2 == 1:
			home = not home
		bag.append({"team": team.duplicate(true), "home": home, "weekend": false, "team_id": str(team.get("team_id", team.get("id", "")))})
		cursor += 1
	var ordered: Array = []
	while not bag.is_empty():
		var pick := 0
		if not ordered.is_empty():
			var last_id := str(ordered.back().get("team_id", ""))
			for i in bag.size():
				if str(bag[i].get("team_id", "")) != last_id:
					pick = i
					break
		ordered.append(bag[pick])
		bag.remove_at(pick)
	for i in ordered.size():
		if i % 5 == 4 and bool(ordered[i].get("home", false)):
			ordered[i]["weekend"] = true
	season_schedule = ordered
	apply_current_fixture()

func apply_current_fixture() -> void:
	if schedule_index < 0 or schedule_index >= season_schedule.size():
		return
	var game: Dictionary = season_schedule[schedule_index]
	is_home_game = bool(game.get("home", true))
	var team: Dictionary = game.get("team", {})
	var tid := str(team.get("team_id", team.get("id", "")))
	for i in opponents.size():
		if str(opponents[i].get("team_id", opponents[i].get("id", ""))) == tid:
			opponent_index = i
			break

func advance_fixture() -> void:
	if season_phase == "regular":
		schedule_index = mini(schedule_index + 1, season_schedule.size())
		apply_current_fixture()
	else:
		is_home_game = club_seed() <= 2

func reset_league_table() -> void:
	league_table.clear()
	league_table[club_team_id()] = {"name": club_name, "team_id": club_team_id(), "w": 0, "l": 0, "pf": 0, "pa": 0, "last5": []}
	for team in ranked_opponents():
		var tid := str(team.get("team_id", team.get("id", "")))
		league_table[tid] = {"name": str(team.get("name", "對手")), "team_id": tid, "w": 0, "l": 0, "pf": 0, "pa": 0, "last5": [], "rating": int(team.get("rating", 70))}

func record_result(tid: String, pts_for: int, pts_against: int, won: bool) -> void:
	if not league_table.has(tid):
		league_table[tid] = {"name": tid, "team_id": tid, "w": 0, "l": 0, "pf": 0, "pa": 0, "last5": []}
	var row: Dictionary = league_table[tid]
	row["w"] = int(row.get("w", 0)) + (1 if won else 0)
	row["l"] = int(row.get("l", 0)) + (0 if won else 1)
	row["pf"] = int(row.get("pf", 0)) + pts_for
	row["pa"] = int(row.get("pa", 0)) + pts_against
	var last5: Array = row.get("last5", [])
	last5.insert(0, "W" if won else "L")
	if last5.size() > 5:
		last5.resize(5)
	row["last5"] = last5
	league_table[tid] = row

func simmer_other_games() -> void:
	var sim_rng := RandomNumberGenerator.new()
	sim_rng.randomize()
	var ids: Array = []
	for tid in league_table.keys():
		if str(tid) == club_team_id():
			continue
		if str(tid) == str(last_opponent.get("team_id", "")):
			continue # The club's opponent already played this round.
		ids.append(str(tid))
	ids.shuffle()
	var i := 0
	while i + 1 < ids.size():
		var a := str(ids[i])
		var b := str(ids[i + 1])
		var team_a: Dictionary = league_table[a].duplicate(true)
		var team_b: Dictionary = league_table[b].duplicate(true)
		# Use the same possession model as the user's game so simulated fixtures
		# reflect rating, pace, offence, defence and natural score variation.
		var simulated: Array[int] = MatchSimulator.game(team_a, team_b, sim_rng)
		var sa := int(simulated[0])
		var sb := int(simulated[1])
		var a_won := sa > sb
		if a_won:
			record_result(a, sa, sb, true)
			record_result(b, sb, sa, false)
		else:
			record_result(b, sb, sa, true)
			record_result(a, sa, sb, false)
		i += 2

func standings_rows() -> Array:
	if league_table.is_empty():
		reset_league_table()
	var rows: Array = []
	for tid in league_table.keys():
		var row: Dictionary = league_table[tid].duplicate(true)
		row["pd"] = int(row.get("pf", 0)) - int(row.get("pa", 0))
		row["self"] = str(tid) == club_team_id()
		if row["self"]:
			row["name"] = club_name
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("w", 0)) != int(b.get("w", 0)):
			return int(a.get("w", 0)) > int(b.get("w", 0))
		if int(a.get("l", 0)) != int(b.get("l", 0)):
			return int(a.get("l", 0)) < int(b.get("l", 0))
		return int(a.get("pd", 0)) > int(b.get("pd", 0))
	)
	if not rows.is_empty():
		var leader: Dictionary = rows[0]
		var lw := int(leader.get("w", 0))
		var ll := int(leader.get("l", 0))
		for row in rows:
			row["gb"] = (float(lw - int(row.get("w", 0))) + float(int(row.get("l", 0)) - ll)) / 2.0
	return rows

func club_seed() -> int:
	var rows := standings_rows()
	for i in rows.size():
		if bool(rows[i].get("self", false)):
			return i + 1
	return rows.size()

func playoff_seed_team(rank_index: int) -> Dictionary:
	var rows := standings_rows()
	var others: Array = []
	for row in rows:
		if bool(row.get("self", false)):
			continue
		others.append(row)
	var pool := ranked_opponents()
	if others.is_empty():
		if pool.is_empty():
			return {"name": "對手", "rating": 74}
		return pool[0]
	var pick: Dictionary = others[clampi(rank_index, 0, others.size() - 1)]
	var tid := str(pick.get("team_id", ""))
	for team in pool:
		if str(team.get("team_id", team.get("id", ""))) == tid:
			var labeled: Dictionary = team.duplicate(true)
			labeled["name"] = "%s%s" % ["四強·" if season_phase == "semifinal" else "冠軍戰·", team.get("name", "對手")]
			return labeled
	return {"name": str(pick.get("name", "對手")), "rating": 74, "team_id": tid}

func in_playoff_cut() -> bool:
	return club_seed() <= int(PlayoffSeries.rules(current_league).cut)

func games_behind_text(row: Dictionary) -> String:
	var gb := float(row.get("gb", 0))
	if gb <= 0.01:
		return "—"
	if absf(gb - roundf(gb)) < 0.01:
		return str(int(roundf(gb)))
	return "%.1f" % gb

func last5_text(row: Dictionary) -> String:
	var last5: Array = row.get("last5", [])
	if last5.is_empty():
		return "—"
	var bits: Array[String] = []
	for item in last5:
		bits.append(str(item))
	return " ".join(bits)

func gameday_n() -> int:
	return mini(team_players.size(), gameday_limit())

func can_field_five() -> bool:
	var local_count := 0
	var foreign_count := 0
	for i in gameday_n():
		if is_foreigner(team_players[i]):
			foreign_count += 1
		else:
			local_count += 1
	return local_count + mini(foreign_count, foreigner_oncourt_limit()) >= 5

func gameday_roster_warning() -> String:
	if can_field_five():
		return ""
	return "%s 場上外援限制下，可用球員不足 5 人；請至少保留更多本土球員。" % current_league

func gameday_unit(preferred: Array, fill: Array) -> Array:
	var unit: Array = []
	var foreign_count := 0
	var first: Array = preferred.duplicate()
	first.shuffle()
	for idx in first:
		if unit.size() >= 5:
			break
		if int(idx) >= 0 and int(idx) < gameday_n() and not unit.has(int(idx)):
			if is_foreigner(team_players[int(idx)]) and foreign_count >= foreigner_oncourt_limit():
				continue
			unit.append(int(idx))
			if is_foreigner(team_players[int(idx)]):
				foreign_count += 1
	var rest: Array = fill.duplicate()
	rest.shuffle()
	for idx in rest:
		if unit.size() >= 5:
			break
		if int(idx) >= 0 and int(idx) < gameday_n() and not unit.has(int(idx)):
			if is_foreigner(team_players[int(idx)]) and foreign_count >= foreigner_oncourt_limit():
				continue
			unit.append(int(idx))
			if is_foreigner(team_players[int(idx)]):
				foreign_count += 1
	return unit

func roll_match_rotation() -> void:
	last_match_oncourt.clear()
	var n := gameday_n()
	if n <= 0:
		return
	var starters: Array = []
	var bench: Array = []
	for i in n:
		if i < 5:
			starters.append(i)
		else:
			bench.append(i)
	last_match_oncourt.append(gameday_unit(starters, bench))
	var q2 := gameday_unit(starters, bench)
	if not bench.is_empty() and n > 5:
		var swaps := randi_range(1, mini(2, bench.size()))
		var sit: Array = starters.duplicate()
		sit.shuffle()
		var come: Array = bench.duplicate()
		come.shuffle()
		for s in swaps:
			if s >= sit.size() or s >= come.size():
				break
			var out_at := q2.find(sit[s])
			if out_at >= 0:
				q2[out_at] = come[s]
			elif q2.size() < 5:
				q2.append(come[s])
	last_match_oncourt.append(q2)
	if bench.size() >= 4:
		last_match_oncourt.append(gameday_unit(bench, starters))
	else:
		last_match_oncourt.append(gameday_unit(bench, starters) if not bench.is_empty() else gameday_unit(starters, bench))
	var q4 := gameday_unit(starters, bench)
	var closer := closer_player()
	var closer_idx := -1
	for i in n:
		if str(team_players[i].get("name", "")) == str(closer.get("name", "")):
			closer_idx = i
			break
	if closer_idx >= 0 and not q4.has(closer_idx):
		if q4.is_empty():
			q4.append(closer_idx)
		else:
			q4[q4.size() - 1] = closer_idx
	elif closer_idx >= 0 and n > 5 and randf() < 0.4:
		var spark: Array = bench.duplicate()
		spark.shuffle()
		if not spark.is_empty() and not q4.has(spark[0]):
			for i in q4.size():
				if int(q4[i]) != closer_idx:
					q4[i] = spark[0]
					break
	last_match_oncourt.append(q4)

func record_match_appearances() -> void:
	# A player earns an appearance once per completed game, even if they rotate
	# through multiple quarters. This is the gate for player development.
	var played: Dictionary = {}
	for unit in last_match_oncourt:
		if unit is Array:
			for raw_index in unit:
				var player_index := int(raw_index)
				if player_index >= 0 and player_index < team_players.size():
					played[player_index] = true
	for player_index in played.keys():
		var player: Dictionary = team_players[int(player_index)]
		player["match_appearances"] = int(player.get("match_appearances", 0)) + 1
		team_players[int(player_index)] = player

func match_minutes_from_rotation() -> PackedInt32Array:
	var n := gameday_n()
	var mins := PackedInt32Array()
	mins.resize(n)
	for q in last_match_oncourt:
		if not (q is Array):
			continue
		for raw in q:
			var idx := int(raw)
			if idx >= 0 and idx < n:
				mins[idx] = mins[idx] + randi_range(10, 13)
	for i in n:
		if mins[i] <= 0 and i < 5:
			mins[i] = randi_range(8, 12)
		elif mins[i] <= 0:
			mins[i] = randi_range(6, 11)
		mins[i] = clampi(mins[i], 4, 40)
	return mins

func oncourt_player(quarter_idx: int) -> Dictionary:
	if quarter_idx < 0 or quarter_idx >= last_match_oncourt.size():
		return team_players[quarter_idx % mini(team_players.size(), 5)] if not team_players.is_empty() else {}
	var unit = last_match_oncourt[quarter_idx]
	if unit is Array and not unit.is_empty():
		var idx := int(unit[randi() % unit.size()])
		if idx >= 0 and idx < team_players.size():
			return team_players[idx]
	return team_players[0] if not team_players.is_empty() else {}

func bench_name_in_quarter(quarter_idx: int) -> String:
	if quarter_idx < 0 or quarter_idx >= last_match_oncourt.size():
		return ""
	var unit = last_match_oncourt[quarter_idx]
	if unit is Array:
		for raw in unit:
			var idx := int(raw)
			if idx >= 5 and idx < team_players.size():
				return str(team_players[idx].get("name", "替補"))
	return ""

func generate_box_sheet(our_score: int) -> void:
	last_box_sheet.clear()
	var n := gameday_n()
	if n <= 0:
		return
	if last_match_oncourt.is_empty():
		roll_match_rotation()
	var mins := match_minutes_from_rotation()
	var weights: Array[float] = []
	var total_w := 0.0
	for i in n:
		var player: Dictionary = team_players[i]
		var w := float(player.get("ovr", 70)) * maxf(6.0, float(mins[i]))
		if i < 5:
			w *= 1.08
		if str(player.get("name", "")) == str(closer_player().get("name", "")):
			w *= 1.12
		weights.append(w)
		total_w += w
	var remain := our_score
	var best_idx := 0
	var best_val := -1.0
	for i in n:
		var player: Dictionary = team_players[i]
		var share := 0.0 if total_w <= 0.0 else weights[i] / total_w
		var floor_pts := 4 if i < 5 else 2
		var cap_pts := 38 if i < 5 else 22
		var pts := clampi(int(round(float(our_score) * share + randf_range(-1.5, 1.5))), floor_pts, cap_pts)
		if i == n - 1:
			pts = clampi(remain, floor_pts, cap_pts)
		remain = maxi(0, remain - pts)
		var min_factor := float(mins[i]) / 28.0
		var reb := clampi(int(round(float(player.get("rpg", 4.0)) * min_factor + randf_range(-1.0, 1.8))), 0, 14)
		var ast := clampi(int(round(float(player.get("apg", 2.0)) * min_factor + randf_range(-0.8, 1.6))), 0, 12)
		var line := {
			"name": str(player.get("name", "球員")),
			"pos": str(player.get("pos", "G")),
			"pts": pts,
			"reb": reb,
			"ast": ast,
			"min": int(mins[i]),
			"starter": i < 5,
		}
		last_box_sheet.append(line)
		var val := float(pts) + float(reb) * 1.2 + float(ast) * 1.5
		if val > best_val:
			best_val = val
			best_idx = i
	var summed := 0
	for line in last_box_sheet:
		summed += int(line.get("pts", 0))
	var gap := our_score - summed
	# Rounding/floors must never invent points or drop points at a per-player cap.
	var cursor := best_idx
	while gap != 0:
		var line: Dictionary = last_box_sheet[cursor]
		if gap > 0:
			line["pts"] = int(line.pts) + 1
			gap -= 1
		elif int(line.pts) > 0:
			line["pts"] = int(line.pts) - 1
			gap += 1
		cursor = (cursor + 1) % last_box_sheet.size()
	best_val = -1.0
	for i in last_box_sheet.size():
		var adjusted: Dictionary = last_box_sheet[i]
		var value := float(adjusted.pts) + float(adjusted.reb) * 1.2 + float(adjusted.ast) * 1.5
		if value > best_val:
			best_val = value
			best_idx = i
	for i in last_box_sheet.size():
		var line: Dictionary = last_box_sheet[i]
		record_club_box_line(i, int(line.get("pts", 0)), int(line.get("reb", 0)), int(line.get("ast", 0)))
	var star: Dictionary = last_box_sheet[best_idx]
	last_mvp = str(star.get("name", last_mvp))
	last_box = {"pts": int(star.get("pts", 0)), "reb": int(star.get("reb", 0)), "ast": int(star.get("ast", 0))}

func record_club_box_line(index: int, pts: int, reb: int, ast: int) -> void:
	if index < 0 or index >= team_players.size():
		return
	var player: Dictionary = team_players[index]
	player["club_gp"] = int(player.get("club_gp", 0)) + 1
	player["club_pts"] = int(player.get("club_pts", 0)) + pts
	player["club_reb"] = int(player.get("club_reb", 0)) + reb
	player["club_ast"] = int(player.get("club_ast", 0)) + ast
	team_players[index] = player

func club_gp(player: Dictionary) -> int:
	return int(player.get("club_gp", 0))

func club_avg(player: Dictionary, total_key: String) -> float:
	var gp := club_gp(player)
	if gp <= 0:
		return 0.0
	return float(player.get(total_key, 0)) / float(gp)

func club_stat_pack(player: Dictionary) -> Dictionary:
	var gp := club_gp(player)
	return {
		"gp": gp,
		"pts": int(player.get("club_pts", 0)),
		"reb": int(player.get("club_reb", 0)),
		"ast": int(player.get("club_ast", 0)),
		"ppg": club_avg(player, "club_pts"),
		"rpg": club_avg(player, "club_reb"),
		"apg": club_avg(player, "club_ast"),
	}

func team_stat_king(total_key: String) -> Dictionary:
	var best: Dictionary = {}
	var best_avg := -0.01
	var best_gp := 0
	for player in team_players:
		if not (player is Dictionary) or club_gp(player) <= 0:
			continue
		var avg := club_avg(player, total_key)
		var gp := club_gp(player)
		if avg > best_avg + 0.0001 or (is_equal_approx(avg, best_avg) and gp > best_gp):
			best_avg = avg
			best_gp = gp
			best = player
	return best

func kings_footnote() -> String:
	var ast: Dictionary = team_stat_king("club_ast")
	if ast.is_empty():
		return "打完場才有平均"
	return "助攻 %s %.1f" % [ast.get("name", "球員"), club_avg(ast, "club_ast")]

func kings_summary_line() -> String:
	var pts: Dictionary = team_stat_king("club_pts")
	if pts.is_empty():
		return "打完一場才有場均排行"
	var reb: Dictionary = team_stat_king("club_reb")
	var ast: Dictionary = team_stat_king("club_ast")
	return "得分 %s %.1f · 籃板 %s %.1f · 助攻 %s %.1f" % [
		pts.get("name", "球員"), club_avg(pts, "club_pts"),
		reb.get("name", "球員"), club_avg(reb, "club_reb"),
		ast.get("name", "球員"), club_avg(ast, "club_ast"),
	]

func roster_index_of(player: Dictionary) -> int:
	var want_id := str(player.get("id", ""))
	var want_name := str(player.get("name", ""))
	for i in team_players.size():
		var item: Dictionary = team_players[i]
		if not want_id.is_empty() and str(item.get("id", "")) == want_id:
			return i
		if str(item.get("name", "")) == want_name and not want_name.is_empty():
			return i
	return -1

func owned_club_stats_block(player: Dictionary) -> Control:
	var pack := club_stat_pack(player)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("0d1c2bed"), GOLD.darkened(0.28), 12, 1))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	panel.add_child(padded(box, 8))
	box.add_child(kicker_label("入隊後數據", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	if int(pack.get("gp", 0)) <= 0:
		box.add_child(wrap_label("還沒幫你出賽。打完場才有總計與場均。", 13, MUTED))
		return panel
	box.add_child(label("%d 場" % int(pack.get("gp", 0)), 13, TEXT, true))
	box.add_child(label("總計  %d 分 / %d 籃板 / %d 助攻" % [int(pack.get("pts", 0)), int(pack.get("reb", 0)), int(pack.get("ast", 0))], 14, TEXT, true))
	box.add_child(label("場均  %.1f 分 / %.1f 籃板 / %.1f 助攻" % [float(pack.get("ppg", 0.0)), float(pack.get("rpg", 0.0)), float(pack.get("apg", 0.0))], 16, GOLD, true))
	return panel

func skill_position_badge(player: Dictionary) -> String:
	var positions := player_pos_list(player)
	if positions.has("C"):
		return "⬢ 中鋒技能"
	if positions.has("PF") or positions.has("SF"):
		return "◆ 前鋒技能"
	return "● 後衛技能"

func clickable_resource(title: String, value: String, accent: Color, action: Callable, hint := "", icon_path := "", compact := false) -> Control:
	var holder := PanelContainer.new()
	var min_w := 88 if title.length() >= 3 else 78
	if not compact:
		min_w = 108 if compact_phone() else 124
	holder.custom_minimum_size = touch_minimum(Vector2(min_w, 40 if compact else (44 if compact_phone() else 52)))
	holder.add_theme_stylebox_override("panel", panel_style(Color(0.06, 0.08, 0.12, 0.82), accent.darkened(0.12), 10 if compact else 12, 1))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 4 if compact else 6)
	holder.add_child(padded(line, 4 if compact else 5))
	if not icon_path.is_empty():
		line.add_child(hud_icon(icon_path, 24 if compact else (28 if compact_phone() else 32)))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", -1)
	line.add_child(box)
	box.add_child(kicker_label(title, 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var node := number_label(value, 14 if compact else (16 if compact_phone() else 18), accent, HORIZONTAL_ALIGNMENT_LEFT)
	node.custom_minimum_size = Vector2(28 if compact else (40 if compact_phone() else 56), 0)
	box.add_child(node)
	var hit := Button.new()
	hit.text = ""
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.tooltip_text = hint
	hit.flat = true
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", panel_style(Color(1, 1, 1, 0.08), accent, 12, 0))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(1, 1, 1, 0.14), TEXT, 12, 0))
	hit.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	holder.add_child(hit)
	return holder

func hud_economy_row(_compact := true) -> Control:
	var row := HBoxContainer.new()
	row.name = "ResourceHUD"
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 4 if is_handheld() else 6)
	resource_hud_labels.clear()
	resource_hud_snapshot.clear()
	for spec in [["budget", "資金", GREEN, "res://assets/ui/hud/budget.png", show_finance_sheet], ["gold", "黃金", GOLD, "res://assets/ui/hud/gold_coin.png", show_store_hub], ["salary", "薪資", GREEN, "res://assets/ui/hud/budget.png", show_salary_sheet], ["scout", "球探點", CYAN, "res://assets/ui/hud/scout.png", show_gacha_market]]:
		var key: String = spec[0]
		var accent: Color = spec[2]
		var destination: Callable = spec[4]
		var chip := Button.new()
		chip.name = "Resource_" + key
		if is_handheld():
			chip.custom_minimum_size = Vector2(UI_RESOURCE_CHIP_WIDTH_PHONE_SALARY if key == "salary" else UI_RESOURCE_CHIP_WIDTH_PHONE, UI_RESOURCE_CHIP_HEIGHT_PHONE)
		else:
			chip.custom_minimum_size = Vector2(UI_RESOURCE_CHIP_WIDTH_DESKTOP_SALARY if key == "salary" else UI_RESOURCE_CHIP_WIDTH_DESKTOP, UI_RESOURCE_CHIP_HEIGHT_DESKTOP)
		chip.add_theme_stylebox_override("normal", panel_style(Color("0b1522ee"), accent.darkened(0.55), 10, 1))
		chip.add_theme_stylebox_override("hover", panel_style(Color("1a2b3bee"), accent, 10, 1))
		chip.add_theme_stylebox_override("pressed", panel_style(Color("23364bee"), accent, 10, 1))
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 3 if is_handheld() else 8
		inner.offset_right = -3 if is_handheld() else -8
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 1 if is_handheld() else 6)
		chip.add_child(inner)
		inner.add_child(hud_icon(spec[3], UI_RESOURCE_ICON_PHONE if is_handheld() else UI_RESOURCE_ICON_DESKTOP))
		var words: BoxContainer = HBoxContainer.new() if is_handheld() else VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_theme_constant_override("separation", 1 if is_handheld() else 0)
		inner.add_child(words)
		var caption := plain_label(spec[1], 9 if is_handheld() else 11, MUTED)
		caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		words.add_child(caption)
		var value := fit_label("", 12 if is_handheld() else 16, accent, true)
		value.name = "ResourceValue_" + key
		words.add_child(value)
		resource_hud_labels[key] = value
		# Keep balances visible during play without allowing navigation to cancel a match.
		chip.pressed.connect(func():
			if current_stage == 6 or match_rewards_pending:
				flash_notice("比賽結束後可開啟資源明細。")
				return
			if key == "salary":
				salary_return_menu = active_menu
			jump_shortcut(destination)
		)
		row.add_child(chip)
	refresh_resource_hud()
	return row

func resource_display_number(raw_value: int, suffix := "") -> String:
	# Keep the value readable in a narrow chip. Values are still exact; only the
	# unit changes once the number would otherwise become an unreadable string.
	var value := maxi(raw_value, 0)
	if suffix == "萬" and value >= 10000:
		var hundred_million := float(value) / 10000.0
		return ("%.1f億" % hundred_million).replace(".0億", "億")
	var digits := str(value)
	var grouped := digits
	# Keep the normal HUD format (for example 3,000 salary cap remains 3000)
	# so existing players recognise it; add grouping only when it materially
	# improves readability for five-digit balances and above.
	if value >= 10000:
		grouped = ""
		while digits.length() > 3:
			grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
			digits = digits.substr(0, digits.length() - 3)
		grouped = digits + grouped
	return grouped + suffix

func resource_value_font_size(text_value: String, base_size: int) -> int:
	# Barlow Condensed is compact, but long balances still need a safe floor.
	var count := text_value.length()
	if count >= 11:
		return maxi(9, base_size - 4)
	if count >= 9:
		return maxi(10, base_size - 3)
	if count >= 7:
		return maxi(11, base_size - 2)
	return base_size

func refresh_resource_hud() -> void:
	if resource_hud_labels.is_empty():
		return
	var used := roster_salary()
	var values := [budget_million, gold, used, salary_cap, scout_points]
	if values == resource_hud_snapshot:
		return
	resource_hud_snapshot = values
	var text_values := {
		"budget": resource_display_number(budget_million, "萬"),
		"gold": resource_display_number(gold),
		"salary": "%s/%s" % [resource_display_number(used), resource_display_number(salary_cap)],
		"scout": resource_display_number(scout_points),
	}
	for key in resource_hud_labels:
		var node = resource_hud_labels[key]
		if not is_instance_valid(node):
			continue
		node.text = text_values[key]
		node.add_theme_font_size_override("font_size", resource_value_font_size(node.text, 12 if is_handheld() else 16))
		if key == "salary":
			node.add_theme_color_override("font_color", RED if used > salary_cap else GREEN)

func clickable_salary(width := 168) -> Control:
	var holder := PanelContainer.new()
	holder.clip_contents = true
	holder.custom_minimum_size = touch_minimum(Vector2(width, 40 if compact_phone() else 48))
	var over := over_salary_cap()
	holder.add_theme_stylebox_override("panel", panel_style(Color(0.08, 0.1, 0.14, 0.78), RED if over else GREEN.darkened(0.2), 12, 1))
	var meter := salary_meter(width - 16)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(padded(meter, 8))
	var hit := Button.new()
	hit.text = ""
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.flat = true
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", panel_style(Color(1, 1, 1, 0.08), GOLD, 12, 0))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(1, 1, 1, 0.14), TEXT, 12, 0))
	hit.tooltip_text = "點進去看出誰最貴"
	hit.pressed.connect(func():
		play_sfx("tap")
		salary_return_menu = active_menu
		open_sub(current_screen_callable(), show_salary_sheet)
	)
	holder.add_child(hit)
	return holder

func match_budget_reward(won: bool) -> int:
	return maxi(0, int(career_rules.get("match_budget_win_million" if won else "match_budget_loss_million", 100 if won else 50)))

func show_finance_sheet() -> void:
	var content := begin_screen("資金明細", "資金可支出 · 薪資帽是名單年薪上限 · 兩者分開計算", 4)
	content.add_child(callout("可用資金", "$%d 萬" % budget_million, GREEN))
	content.add_child(callout("收入", "新俱樂部初始資金 300 萬、黃金 100、球探點 20。每場結算勝場 +%d 萬、敗場 +%d 萬（含額外比賽）。勝利黃金 5～10；球探點依連勝加成。" % [match_budget_reward(true), match_budget_reward(false)], CYAN))
	content.add_child(callout("支出", "自由簽約：年薪 × 1.2（最低 45 萬）；交易費依對象另計；養成特訓每次消耗 1 特訓點＋20 萬資金，完全不使用黃金。簽約後年薪另外計入薪資帽。球探購買只扣球探點，換下一批只扣 20 黃金。", GOLD))

func show_salary_sheet() -> void:
	var back_menu := salary_return_menu
	var used := roster_salary()
	var cap := maxi(1, salary_cap)
	var content := begin_screen("薪資明細", "每人年薪加總對薪資帽 · 黃金不能墊薪資", 4)
	content.add_child(salary_meter(280 if compact_phone() else 360))
	content.add_child(callout("帽子", "目前 $%d／$%d 萬 · 剩餘 $%d 萬%s" % [used, cap, maxi(0, cap - used), " · 已超帽，先釋出或換人" if used > cap else ""], RED if used > cap else GREEN))
	var rows: Array[Dictionary] = []
	for i in team_players.size():
		var player: Dictionary = team_players[i]
		rows.append({
			"player": player,
			"index": i,
			"pay": int(float(player.get("salary_million", published_salary(player)))),
		})
	rows.sort_custom(func(a, b): return int(a.get("pay", 0)) > int(b.get("pay", 0)))
	for row in rows:
		var player: Dictionary = row.get("player", {})
		var idx := int(row.get("index", 0))
		var pay := int(row.get("pay", 0))
		var who := identity_label(player)
		var role := "先發" if idx < 5 else ("登錄" if idx < 12 else "未登錄")
		content.add_child(salary_player_row(player, role, who, pay))
	var coach := coach_data(coach_id)
	var coach_pay := int(coach.get("cost_salary", 0))
	if coach_pay > 0:
		content.add_child(callout("教練", "%s · 年薪 $%d 萬（算進薪資帽）" % [str(coach.get("name", "教練")), coach_pay], ORANGE))

func salary_player_row(player: Dictionary, role: String, who: String, pay: int) -> Control:
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(0, 52)
	shell.add_theme_stylebox_override("panel", panel_style(Color(0.07, 0.09, 0.12, 0.82), identity_accent(player).darkened(0.3), 10, 1))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	shell.add_child(padded(line, 8))
	line.add_child(simple_bust(player, 36))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	words.add_child(fit_label("%s  %s" % [player.get("pos", player.get("position", "G")), player.get("name", "球員")], 14, TEXT, true))
	words.add_child(fit_label("%s · %s · OVR %d" % [role, who, int(player.get("ovr", 70))], 11, MUTED))
	line.add_child(plain_label("$%d 萬" % pay, 15, GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT))
	return shell

func official_account_email() -> String:
	return str(auth_email if not auth_email.is_empty() else login_email).strip_edges().to_lower()

func is_official_tester() -> bool:
	var mail := official_account_email()
	if mail.is_empty():
		return false
	if mail == "eve1995927@gmail.com":
		return true
	return mail.contains("yongye") or mail.contains("hulk")

func designer_preview() -> bool:
	# 編輯器方便排版。匯出的 DEBUG 不當成全開測試帳。
	return OS.has_feature("editor") or is_official_tester()

func apply_designer_unlocks() -> void:
	if not designer_preview():
		return
	pro_top2 = true
	easl_pass = true
	jones_pass = true
	national_unlocked = true
	if is_official_tester():
		fill_official_tester_account()

func fill_official_tester_account() -> void:
	budget_million = maxi(budget_million, 9999)
	gold = maxi(gold, 9999)
	scout_points = maxi(scout_points, 99)
	training_points = maxi(training_points, 20)
	salary_cap_bonus = maxi(salary_cap_bonus, 5000)
	apply_salary_cap()
	extra_save_unlocked = true
	iap_receipts["easl"] = true
	iap_receipts["jones"] = true
	iap_receipts["extra_save"] = true
	iap_receipts["national_%d" % active_save_slot] = true
	if not unlocked_leagues.has("PLG"):
		unlocked_leagues.append("PLG")
	if not unlocked_leagues.has("TPBL"):
		unlocked_leagues.append("TPBL")
	for item in career_rules.get("coaches", []):
		if item is Dictionary:
			var cid := str(item.get("id", ""))
			if not cid.is_empty() and not coaches_owned.has(cid):
				coaches_owned.append(cid)
	for team in league_teams:
		for raw in team.get("players", []):
			if raw is Dictionary:
				var league_card := to_game_player(raw)
				if not team_has_player(league_card):
					card_inventory.append(league_card)
	for raw in public_players:
		var pub_card := to_game_player(raw)
		if not team_has_player(pub_card):
			card_inventory.append(pub_card)
	for item in career_rules.get("golden_generation", []):
		if item is Dictionary:
			var vet := to_game_player(item)
			if not team_has_player(vet):
				card_inventory.append(vet)
	for prize_id in ["liu", "davis", "hebo", "chen", "lin"]:
		grant_prize_card(prize_id, false)
	lin_hidden_granted = true
	compact_unique_owned()
	apply_combo_label()

func extra_can_play(event_id: String) -> bool:
	if designer_preview():
		return true
	return pro_top2 and extra_event_unlocked(event_id)

func pending_unlock_box(price: String, why: String) -> Control:
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.custom_minimum_size = Vector2(0, 48)
	shell.add_theme_stylebox_override("panel", panel_style(Color("3a4048e8"), Color("8d97a4"), 12, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(padded(row, 8))
	row.add_child(label("待解鎖", 16, MUTED, true))
	if not price.is_empty():
		row.add_child(label(price, 15, GOLD, true))
	if not why.is_empty():
		var hint := fit_label(why, 12, MUTED, false)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hint)
	return shell

func league_open(code: String) -> bool:
	if code == "EASL" or code == "BCL":
		return designer_preview() or (easl_pass and pro_top2)
	return unlocked_leagues.has(code)

func origin_id(player: Dictionary) -> String:
	if bool(player.get("combo_flex_paid", false)):
		var flex := str(player.get("combo_flex_origin", ""))
		if not flex.is_empty():
			return flex
	var origin := str(player.get("origin_team_id", ""))
	if origin.is_empty():
		origin = team_id_from_display_name(str(player.get("team", "")))
	return origin

func team_display_name(team_id: String) -> String:
	if team_id.is_empty():
		return ""
	if FICTIONAL_TEAM_NAMES.has(team_id):
		return str(FICTIONAL_TEAM_NAMES[team_id])
	for team in league_teams:
		if str(team.get("id", "")) == team_id:
			return str(team.get("name", ""))
	return ""

func team_short_name(team_id: String) -> String:
	var short := str(TEAM_SHORT.get(team_id, ""))
	if not short.is_empty():
		return short
	return team_display_name(team_id)

func golden_generation_profile(raw: Dictionary) -> Dictionary:
	var who := str(raw.get("name", ""))
	if who.is_empty():
		return {}
	for item in career_rules.get("golden_generation", []):
		if item is Dictionary and str(item.get("name", "")) == who:
			return item
	return {}

func veteran_prime_team_id(player: Dictionary) -> String:
	var profile := golden_generation_profile(player)
	return str(profile.get("prime_team_id", "")) if not profile.is_empty() else ""

func veteran_prime_team_name(player: Dictionary) -> String:
	var profile := golden_generation_profile(player)
	return str(profile.get("prime_team_name", "")) if not profile.is_empty() else ""

func veteran_prime_logo(player: Dictionary) -> Texture2D:
	var profile := golden_generation_profile(player)
	if profile.is_empty():
		return null
	var asset := str(profile.get("prime_team_logo_asset", ""))
	if not asset.is_empty():
		return team_logo_tex("asset:" + asset)
	var team_id := str(profile.get("prime_team_id", ""))
	return team_logo_tex(team_id) if not team_id.is_empty() else null

func is_veteran_player(raw: Dictionary) -> bool:
	return not golden_generation_profile(raw).is_empty()

func is_combo_wild(player: Dictionary) -> bool:
	# Every diamond card is a free wildcard and counts toward the strongest team
	# combination. No salary payment or manual assignment is required.
	return bool(player.get("combo_wild", false)) or player_tier_key(player) == "diamond"

func veteran_count() -> int:
	var n := 0
	for player in team_players:
		if is_veteran_player(player):
			n += 1
	return n

func apply_veteran_card(player: Dictionary) -> Dictionary:
	var profile := golden_generation_profile(player)
	if profile.is_empty():
		return player
	player["golden_generation"] = true
	# Historical club identity is presentation data; keep origin_team_id intact
	# so squad-combo rules are not silently changed by an old card.
	var prime_id := str(profile.get("prime_team_id", ""))
	var prime_name := str(profile.get("prime_team_name", ""))
	var prime_asset := str(profile.get("prime_team_logo_asset", ""))
	if not prime_id.is_empty():
		player["prime_team_id"] = prime_id
	if not prime_name.is_empty():
		player["prime_team_name"] = prime_name
	if not prime_asset.is_empty():
		player["prime_team_logo_asset"] = prime_asset
	# Veteran cards use the curated historical position, even when a public
	# roster entry has an incomplete or outdated position.
	var veteran_pos := str(profile.get("position", ""))
	if not veteran_pos.is_empty():
		player["position"] = veteran_pos
		player["pos"] = veteran_pos
	if bool(profile.get("retired", false)):
		player["retired"] = true
	player["skill_id"] = "veteran_leadership"
	var trained := int(player.get("training_sessions", 0))
	if trained <= 0:
		player["ovr"] = clampi(int(profile.get("ovr", 72)), 65, 90)
		player["potential"] = mini(90, int(player.get("ovr", 72)) + 2)
	player["salary_million"] = published_salary(player)
	player["color"] = "gold"
	return player

func veteran_unlocked(raw: Dictionary) -> bool:
	var pid := str(raw.get("id", raw.get("name", "")))
	return veteran_cleared.has(pid)

func roster_salary() -> int:
	var total := 0
	for player in team_players:
		total += int(float(player.get("salary_million", 180.0)))
	var coach := coach_data(coach_id)
	total += int(coach.get("cost_salary", 0))
	return total

func default_club_name() -> String:
	return "台北烈焰俱樂部"

func ensure_club_name() -> String:
	var club_title := club_name.strip_edges()
	if club_title.is_empty() or club_title == "未命名俱樂部":
		club_name = default_club_name()
	return club_name

func club_name_edit_button(caption: String, font_size := 17) -> Button:
	var hit := Button.new()
	hit.text = caption
	hit.flat = true
	hit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hit.tooltip_text = "點一下修改俱樂部名稱"
	hit.add_theme_font_override("font", FONT_BOLD)
	hit.add_theme_font_size_override("font_size", font_size)
	hit.add_theme_color_override("font_color", TEXT)
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", invisible_style())
	hit.add_theme_stylebox_override("pressed", invisible_style())
	hit.pressed.connect(func(): show_rename_club_modal())
	return hit

func show_rename_club_modal() -> void:
	close_guide_modal()
	var veil := ColorRect.new()
	guide_modal = veil
	veil.name = "RenameClubModal"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.03, 0.05, 0.72)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 50
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(500 if compact_phone() else 560, 220)
	sheet.add_theme_stylebox_override("panel", panel_style(Color("0c1927fc"), GOLD, 18, 2))
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	sheet.add_child(padded(box, 16))
	box.add_child(label("修改俱樂部名稱", 20, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(wrap_label("名稱需為 2–14 個字；組合隊伍名稱會自動接在後方。", 13, MUTED, true))
	var input := text_field("俱樂部名稱 2–14 字", club_name)
	input.name = "ClubRenameInput"
	box.add_child(input)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var cancel := action_button("取消", Color("27394a"), func(): close_guide_modal())
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(cancel)
	var confirm := gold_action_button("儲存名稱", func():
		var typed := input.text.strip_edges()
		if typed.length() < 2 or typed.length() > 14:
			flash_notice("俱樂部名稱請輸入 2–14 個字")
			return
		club_name = typed
		last_event = "俱樂部已改名為 %s。" % club_name
		save_game()
		close_guide_modal()
		show_dashboard()
		flash_notice("名稱已更新：%s" % club_name)
	)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(confirm)

func wan_text(amount: int) -> String:
	var prefix := "-" if amount < 0 else ""
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return "%s$%s%s 萬" % [prefix, digits, grouped]

func coach_data(cid: String) -> Dictionary:
	for item in career_rules.get("coaches", []):
		if item is Dictionary and str(item.get("id", "")) == cid:
			return item
	return {"id": "sbl_rookie", "name": "基礎組織教練", "cost_salary": 0, "cost_gold": 0, "offense": 0.04, "defense": 0.02, "blurb": "半場傳導較穩。"}

func origin_tally() -> Dictionary:
	var counts: Dictionary = {}
	var wild := 0
	for i in mini(team_players.size(), gameday_limit()):
		var card: Dictionary = team_players[i]
		if is_combo_wild(card) or is_veteran_player(card):
			wild += 1
			continue
		var origin := origin_id(card)
		if origin.is_empty():
			continue
		counts[origin] = int(counts.get(origin, 0)) + 1
	if wild <= 0 or counts.is_empty():
		return counts
	var lead := ""
	var best := 0
	for key in counts.keys():
		var n := int(counts[key])
		if n > best:
			best = n
			lead = str(key)
	if not lead.is_empty():
		counts[lead] = best + wild
	return counts

func top_origin_id() -> String:
	var counts := origin_tally()
	var best := ""
	var best_n := 0
	for origin in counts.keys():
		var n := int(counts[origin])
		if n > best_n:
			best_n = n
			best = str(origin)
	return best

func combo_origin_label(origin: String) -> String:
	if origin.is_empty():
		return "組合隊伍"
	var short := team_short_name(origin)
	if not short.is_empty():
		return short
	for item in career_rules.get("combos", []):
		if item is Dictionary and str(item.get("origin", "")) == origin:
			return str(item.get("label", origin)).replace("班底", "").strip_edges()
	return origin

func combo_next_step(count: int) -> Dictionary:
	if count >= 12:
		return {"need": 12, "bonus": 4}
	if count >= 10:
		return {"need": 12, "bonus": 4}
	if count >= 7:
		return {"need": 10, "bonus": 3}
	if count >= 5:
		return {"need": 7, "bonus": 2}
	return {"need": 5, "bonus": 1}

func combo_progress_state() -> Dictionary:
	var counts := origin_tally()
	var origin := ""
	var n := 0
	for key in counts.keys():
		var c := int(counts[key])
		if c > n:
			n = c
			origin = str(key)
	var nxt := combo_next_step(n)
	var next_need := int(nxt.get("need", 5))
	return {
		"origin": origin,
		"count": n,
		"bonus": combo_step_bonus(n, origin),
		"label": combo_origin_label(origin),
		"next_need": next_need,
		"next_bonus": combo_step_bonus(next_need, origin),
	}

func combo_state() -> Dictionary:
	var st := combo_progress_state()
	if int(st.get("count", 0)) < 5:
		return {}
	return st

func combo_step_bonus(count: int, origin_or_national: Variant = "") -> int:
	var bonus := 0
	if count >= 12:
		bonus = 4
	elif count >= 10:
		bonus = 3
	elif count >= 7:
		bonus = 2
	elif count >= 5:
		bonus = 1
	if origin_or_national is bool and bool(origin_or_national) and bonus > 0:
		bonus = int(round(float(bonus) * 1.5))
	elif origin_or_national is String and not str(origin_or_national).is_empty():
		var origin_league := ""
		for team in league_teams:
			if str(team.get("id", "")) == str(origin_or_national):
				origin_league = str(team.get("league", ""))
				break
		if origin_league in ["PLG", "TPBL"]:
			bonus *= 2
	return bonus

func combo_ovr_bonus(_player: Dictionary, _index: int) -> int:
	return 0

func combo_rule_line() -> String:
	var st := combo_progress_state()
	var n := int(st.get("count", 0))
	if n < 5:
		return "SBL 同隊 5／7／10／12 人 → +1／+2／+3／+4；PLG／TPBL 加成兩倍。鑽石卡免費算任何隊。"
	if n >= 12:
		return "%s：%d 人登錄，隊伍 +%d OVR（滿階）" % [st.get("label", "組合隊伍"), n, int(st.get("bonus", 8))]
	return "%s：%d 人登錄，隊伍 +%d OVR · 再 %d 人到 +%d" % [st.get("label", "組合隊伍"), n, int(st.get("bonus", 2)), int(st.get("next_need", 7)) - n, int(st.get("next_bonus", 4))]

func combo_bonus_headline() -> String:
	var st := combo_progress_state()
	var bonus := int(st.get("bonus", 0))
	if bonus > 0:
		return "隊伍 +%d OVR" % bonus
	return "尚未加成"

func apply_combo_label() -> void:
	var st := combo_progress_state()
	var bonus := int(st.get("bonus", 0))
	if bonus > 0:
		combo_label = "%s +%d" % [st.get("label", "組合隊伍"), bonus]
	else:
		combo_label = "尚未組成"

func combo_status_chip() -> Control:
	apply_combo_label()
	var st := combo_state()
	if st.is_empty():
		var blank := Control.new()
		blank.visible = false
		blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return blank
	var bonus := int(st.get("bonus", 0))
	var accent := GOLD
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shell.add_theme_stylebox_override("panel", panel_style(Color(0.08, 0.07, 0.04, 0.86), accent.darkened(0.18), 10, 1))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	shell.add_child(padded(row, 4))
	var origin := str(st.get("origin", ""))
	if not origin.is_empty():
		row.add_child(team_logo_rect(origin, 22, str(st.get("label", ""))))
	var short := "%s +%d" % [st.get("label", "組合隊伍"), bonus]
	var mark := plain_label(short, 12, accent, true, HORIZONTAL_ALIGNMENT_LEFT)
	mark.clip_text = true
	mark.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mark.custom_minimum_size = Vector2(86, 0)
	row.add_child(mark)
	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", invisible_style())
	hit.add_theme_stylebox_override("pressed", invisible_style())
	hit.pressed.connect(func():
		play_sfx("tap")
		show_combo_overview()
	)
	shell.add_child(hit)
	return shell

func combo_status_banner(compact := false) -> Control:
	apply_combo_label()
	var st := combo_progress_state()
	var bonus := int(st.get("bonus", 0))
	var accent := GOLD if bonus > 0 else CYAN
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shell.add_theme_stylebox_override("panel", panel_style(Color(0.08, 0.07, 0.04, 0.78), accent.darkened(0.15), 12, 2 if bonus > 0 else 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(padded(row, 6 if compact else 8))
	var origin := str(st.get("origin", ""))
	if not origin.is_empty():
		row.add_child(team_logo_rect(origin, 28 if compact else 36, str(st.get("label", ""))))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	words.add_child(plain_label("組合隊伍", 11, MUTED, true))
	words.add_child(fit_label(combo_rule_line(), 13 if compact else 15, TEXT if bonus <= 0 else GOLD, true))
	row.add_child(plain_label(combo_bonus_headline(), 16 if compact else 18, accent, true, HORIZONTAL_ALIGNMENT_RIGHT))
	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", invisible_style())
	hit.add_theme_stylebox_override("pressed", invisible_style())
	hit.pressed.connect(func():
		play_sfx("tap")
		show_combo_overview()
	)
	shell.add_child(hit)
	return shell

func compact_combo_chip() -> Control:
	apply_combo_label()
	var st := combo_progress_state()
	var bonus := int(st.get("bonus", 0))
	var accent := GOLD if bonus > 0 else CYAN
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(168 if compact_phone() else 218, 40 if compact_phone() else 44)
	shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shell.clip_contents = true
	shell.add_theme_stylebox_override("panel", panel_style(Color(0.08, 0.07, 0.04, 0.78), accent.darkened(0.15), 10, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(padded(row, 4))
	var origin := str(st.get("origin", ""))
	if not origin.is_empty():
		row.add_child(team_logo_rect(origin, 22, str(st.get("label", ""))))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	words.add_child(kicker_label("組合隊伍", 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	words.add_child(fit_label("同出身 %d／12 人" % int(st.get("count", 0)), 10, TEXT, true))
	row.add_child(plain_label(combo_bonus_headline(), 10, accent, true, HORIZONTAL_ALIGNMENT_RIGHT))
	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", invisible_style())
	hit.add_theme_stylebox_override("pressed", invisible_style())
	hit.pressed.connect(func():
		play_sfx("tap")
		show_combo_overview()
	)
	shell.add_child(hit)
	return shell

func combo_team_bonus() -> int:
	var combo := combo_state()
	if combo.is_empty():
		return 0
	return int(combo.get("bonus", 0))

func club_combo_logo_id() -> String:
	var combo := combo_state()
	if not combo.is_empty():
		return str(combo.get("origin", ""))
	return top_origin_id()

func ensure_club_logo_id() -> String:
	for item in CLUB_LOGOS:
		if str(item.get("id", "")) == club_logo_id:
			return club_logo_id
	club_logo_id = "club_01"
	return club_logo_id

func club_logo_title(logo_id := "") -> String:
	var want := logo_id if not logo_id.is_empty() else ensure_club_logo_id()
	for item in CLUB_LOGOS:
		if str(item.get("id", "")) == want:
			return str(item.get("name", "隊徽"))
	return "隊徽"

func club_logo_button(px: int, action: Callable) -> Control:
	var hit := Button.new()
	hit.custom_minimum_size = Vector2(px, px)
	hit.clip_contents = true
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", panel_style(Color(0.08, 0.07, 0.04, 0.9), GOLD, 10, 1))
	hit.add_theme_stylebox_override("hover", panel_style(Color(0.12, 0.1, 0.05, 0.95), ORANGE, 10, 1))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(0.06, 0.05, 0.03, 0.95), TEXT, 10, 1))
	var art := team_logo_rect(ensure_club_logo_id(), px - 8, club_name)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 4
	art.offset_top = 4
	art.offset_right = -4
	art.offset_bottom = -4
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.add_child(art)
	hit.pressed.connect(func():
		play_sfx("tap")
		if action.is_valid():
			action.call()
	)
	bind_press_juice(hit, hit)
	return hit

func club_display_name() -> String:
	var combo := combo_state()
	if not combo.is_empty():
		return "%s - %s" % [club_name, str(combo.get("label", "組合隊伍"))]
	return club_name

func team_accent(team_id: String) -> Color:
	match team_id:
		"fubon":
			return Color("1d4ed8")
		"pilots":
			return Color("f97316")
		"ghosthawks":
			return Color("b91c1c")
		"yankey":
			return Color("0891b2")
		"dreamers":
			return Color("65a30d")
		"lioneers":
			return Color("7c3aed")
		"aquas":
			return Color("0284c7")
		"dea":
			return Color("facc15")
		"kings":
			return Color("facc15")
		"mars":
			return Color("dc2626")
		"leopards":
			return Color("15803d")
		"sbl_pure":
			return Color("7c3aed")
		"sbl_kites":
			return Color("0f766e")
		"sbl_bank":
			return Color("166534")
		"sbl_beer":
			return Color("15803d")
		"sbl_yulon":
			return Color("1d4ed8")
		"nt_japan":
			return Color("bc002d")
		"nt_china":
			return Color("de2910")
		"nt_korea":
			return Color("0047a0")
		"nt_taipei":
			return Color("002f87")
		"nt_jordan":
			return Color("ce1126")
		"nt_malaysia":
			return Color("cc0000")
		"jones_db":
			return Color("167a3a")
		"jones_uci":
			return Color("0c2340")
		"jones_sga":
			return Color("0e1c3a")
		_:
			return GOLD

func team_mark_letter(team_id: String, fallback_name := "") -> String:
	var mark := str(TEAM_MARK.get(team_id, ""))
	if not mark.is_empty():
		return mark
	if not fallback_name.is_empty():
		return fallback_name.substr(0, 1)
	if not team_id.is_empty():
		return team_id.substr(0, 1).to_upper()
	return "球"

func national_logo_id(team_id: String, name := "") -> String:
	var key := team_id.strip_edges()
	if key.is_empty():
		key = name.strip_edges()
	match key:
		"nt_japan", "日本", "jones_japan":
			return "nt_japan"
		"nt_china", "中國":
			return "nt_china"
		"nt_korea", "韓國":
			return "nt_korea"
		"nt_taipei", "中華台北", "中華藍", "中華白", "jones_blue", "jones_white":
			return "nt_taipei"
		"nt_jordan", "約旦", "jones_jordan":
			return "nt_jordan"
		"nt_malaysia", "馬來西亞", "jones_mas":
			return "nt_malaysia"
		"jones_db", "原州DB新世代":
			return "jones_db"
		"jones_uci", "加州大學爾灣分校":
			return "jones_uci"
		"jones_sga", "菲律賓Strong Group":
			return "jones_sga"
		_:
			return key if not key.is_empty() else team_id

func is_national_flag(team_id: String) -> bool:
	return national_logo_id(team_id).begins_with("nt_")

func team_logo_tex(team_id: String) -> Texture2D:
	if team_id.is_empty():
		return null
	# Historical veteran cards may reference an exact bundled asset (including
	# webp), independent of the current fictional league team id.
	if team_id.begins_with("asset:"):
		var asset_path := team_id.trim_prefix("asset:")
		var asset_key := "logo#asset#%s" % asset_path
		if _tex_cache.has(asset_key) and _tex_cache[asset_key] is Texture2D:
			return _tex_cache[asset_key]
		var historical := load_png_tex("res://%s" % asset_path)
		if historical == null:
			return null
		var cut_historical := knockout_white_logo(historical)
		_tex_cache[asset_key] = cut_historical
		return cut_historical
	if team_id.begins_with("club_"):
		var club_key := "logo#club#%s" % team_id
		if _tex_cache.has(club_key) and _tex_cache[club_key] is Texture2D:
			return _tex_cache[club_key]
		var club_tex := load_png_tex("res://assets/ui/club_logos/%s.png" % team_id)
		if club_tex != null:
			_tex_cache[club_key] = club_tex
		return club_tex
	var resolved := national_logo_id(team_id)
	var key := "logo#cut#%s" % resolved
	if _tex_cache.has(key) and _tex_cache[key] is Texture2D:
		return _tex_cache[key]
	var raw: Texture2D = null
	for ext in ["png", "webp", "jpg"]:
		raw = load_png_tex("res://assets/ui/team_logos/%s.%s" % [resolved, ext])
		if raw != null:
			break
	if raw == null:
		for folder in ["images", "portraits"]:
			for ext in ["png", "webp", "jpg"]:
				raw = load_png_tex("res://assets/%s/teams/%s/logo/official.%s" % [folder, resolved, ext])
				if raw != null:
					break
			if raw != null:
				break
	if raw == null:
		return null
	if is_national_flag(resolved):
		_tex_cache[key] = raw
		return raw
	var cut := knockout_white_logo(raw)
	_tex_cache[key] = cut
	return cut

func knockout_white_logo(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	if w < 4 or h < 4:
		return tex
	var trans_n := 0
	for pos in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		if img.get_pixel(pos.x, pos.y).a < 0.08:
			trans_n += 1
	if trans_n < 3:
		var data := img.get_data()
		var vis := PackedByteArray()
		vis.resize(w * h)
		var q: Array[int] = []
		for x in w:
			_logo_try_seed(data, vis, q, x, 0, w)
			_logo_try_seed(data, vis, q, x, h - 1, w)
		for y in range(1, h - 1):
			_logo_try_seed(data, vis, q, 0, y, w)
			_logo_try_seed(data, vis, q, w - 1, y, w)
		var qi := 0
		while qi < q.size():
			var p: int = q[qi]
			qi += 1
			data[p * 4 + 3] = 0
			var x := p % w
			var y := int(p / w)
			if x > 0:
				_logo_try_seed(data, vis, q, x - 1, y, w)
			if x + 1 < w:
				_logo_try_seed(data, vis, q, x + 1, y, w)
			if y > 0:
				_logo_try_seed(data, vis, q, x, y - 1, w)
			if y + 1 < h:
				_logo_try_seed(data, vis, q, x, y + 1, w)
		img.set_data(w, h, false, Image.FORMAT_RGBA8, data)
	img = crop_transparent_margin(img)
	return ImageTexture.create_from_image(img)

func crop_transparent_margin(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in h:
		for x in w:
			if data[(y * w + x) * 4 + 3] > 24:
				if x < minx:
					minx = x
				if y < miny:
					miny = y
				if x > maxx:
					maxx = x
				if y > maxy:
					maxy = y
	if maxx < minx:
		return img
	var pad := 2
	minx = maxi(0, minx - pad)
	miny = maxi(0, miny - pad)
	maxx = mini(w - 1, maxx + pad)
	maxy = mini(h - 1, maxy + pad)
	return img.get_region(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))

func _logo_byte_is_bg(data: PackedByteArray, idx: int) -> bool:
	if data[idx + 3] < 16:
		return true
	var r: int = data[idx]
	var g: int = data[idx + 1]
	var b: int = data[idx + 2]
	var mx := maxi(r, maxi(g, b))
	var mn := mini(r, mini(g, b))
	return (mx >= 230 and (mx - mn) <= 32) or (mx >= 209 and (mx - mn) <= 16)

func _logo_try_seed(data: PackedByteArray, vis: PackedByteArray, q: Array, x: int, y: int, w: int) -> void:
	var p := y * w + x
	if vis[p] != 0:
		return
	if not _logo_byte_is_bg(data, p * 4):
		return
	vis[p] = 1
	q.append(p)

func team_logo_rect(team_id: String, px := 44, fallback_name := "") -> Control:
	var tex := team_logo_tex(team_id)
	if tex != null:
		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(px, px)
		art.texture = tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return art
	var accent := team_accent(team_id)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(px, px)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", panel_style(accent, Color(1, 1, 1, 0.4), int(px / 2.0), 1))
	var mark := plain_label(team_mark_letter(team_id, fallback_name), clampi(int(px * 0.42), 11, 18), TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badge.add_child(mark)
	return badge

func home_banner_mark(px := 40) -> Control:
	return team_logo_rect(ensure_club_logo_id(), px, club_display_name())

func national_event_data(event_id := "") -> Dictionary:
	var want := event_id if not event_id.is_empty() else national_event
	for item in career_rules.get("national_events", []):
		if item is Dictionary and str(item.get("id", "")) == want:
			return item
	return {}

func national_event_names(event_id := "") -> Array[String]:
	var names: Array[String] = []
	var data := national_event_data(event_id)
	for item in data.get("names", []):
		names.append(str(item))
	return names

func national_event_unlocked(event_id: String) -> bool:
	if event_id == "jones_white":
		return true
	if event_id == "jones_blue":
		return national_progress in ["jones_blue", "asia_cup"]
	if event_id == "asia_cup":
		return national_progress == "asia_cup"
	return false

func owned_player_named(wanted: String) -> Dictionary:
	for player in team_players:
		if str(player.get("name", "")) == wanted:
			return player
	for raw in card_inventory:
		if raw is Dictionary and str(raw.get("name", "")) == wanted:
			return to_game_player(raw)
	return {}

func national_owned_players(event_id := "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wanted in national_event_names(event_id):
		var owned := owned_player_named(wanted)
		if owned.is_empty():
			continue
		if result.any(func(item: Dictionary): return str(item.get("name", "")) == wanted):
			continue
		result.append(owned)
	return result

func national_combo_bonus() -> int:
	return combo_step_bonus(national_owned_players().size(), true)

func refresh_tactic_unlocks() -> void:
	if not unlocked_offense.has("快節奏轉換"):
		unlocked_offense.append("快節奏轉換")
	if not unlocked_defense.has("人盯人"):
		unlocked_defense.append("人盯人")
	for kind in ["offense", "defense"]:
		for item in tactic_catalog(kind):
			if not (item is Dictionary):
				continue
			var tactic_id := str(item.get("id", ""))
			if tactic_id.is_empty() or not tactic_meets_unlock(str(item.get("unlock", "start"))):
				continue
			if kind == "offense" and not unlocked_offense.has(tactic_id):
				unlocked_offense.append(tactic_id)
			elif kind == "defense" and not unlocked_defense.has(tactic_id):
				unlocked_defense.append(tactic_id)
	var after: Array = []
	for item in unlocked_offense:
		after.append(str(item))
	for item in unlocked_defense:
		after.append(str(item))
	if last_known_unlocks.is_empty():
		last_known_unlocks = after
		return
	for item in after:
		if not last_known_unlocks.has(item):
			push_news("戰術解鎖：%s。去編隊套用，不花黃金。" % item)
			last_news = "戰術解鎖：%s" % item
	last_known_unlocks = after

func tactic_meets_unlock(unlock: String) -> bool:
	if unlock == "start" or unlock.is_empty():
		return true
	if unlock.begins_with("wins:"):
		return season_wins >= int(unlock.get_slice(":", 1))
	if unlock.begins_with("games:"):
		return maxi(season_games, regular_games) >= int(unlock.get_slice(":", 1))
	if unlock == "champion:SBL":
		return bool(championships.get("SBL", false))
	if unlock == "league:PLG":
		return league_open("PLG") or current_league == "PLG"
	if unlock == "league:TPBL":
		return league_open("TPBL") or current_league == "TPBL"
	if unlock == "top2:pro":
		return pro_top2
	return false

func tactic_catalog(kind: String) -> Array:
	var pack: Dictionary = career_rules.get("tactics", {})
	var rows = pack.get(kind, [])
	return rows if rows is Array else []

func tactic_blurb(tactic: String) -> Dictionary:
	for kind in ["offense", "defense"]:
		for item in tactic_catalog(kind):
			if item is Dictionary and str(item.get("id", "")) == tactic:
				return item
	return {}

func tactic_unlocked_now(tactic: String, offense: bool) -> bool:
	if offense:
		return unlocked_offense.has(tactic)
	return unlocked_defense.has(tactic)

func tactic_unlock_hint(unlock: String) -> String:
	if unlock == "start":
		return "開局即可使用"
	if unlock.begins_with("wins:"):
		var need := int(unlock.get_slice(":", 1))
		var left := maxi(0, need - season_wins)
		if left <= 0:
			return "已達成：本季勝場 %d" % need
		return "任務：再贏 %d 場（本季 %d／%d 勝）" % [left, season_wins, need]
	if unlock.begins_with("games:"):
		var need := int(unlock.get_slice(":", 1))
		var played := maxi(season_games, regular_games)
		var left := maxi(0, need - played)
		if left <= 0:
			return "已達成：出賽 %d 場" % need
		return "任務：再打 %d 場（目前 %d／%d）" % [left, played, need]
	if unlock == "champion:SBL":
		return "任務：拿下 SBL 冠軍"
	if unlock == "league:PLG":
		return "任務：進入 PLG 後解鎖"
	if unlock == "league:TPBL":
		return "任務：進入 TPBL 後解鎖"
	if unlock == "top2:pro":
		return "任務：PLG 或 TPBL 例行賽前二"
	if unlock.is_empty():
		return "完成對應任務後解鎖"
	return "任務：%s" % unlock

func tactic_unlock_progress(unlock: String) -> Dictionary:
	if unlock.begins_with("wins:"):
		var need := int(unlock.get_slice(":", 1))
		return {"value": mini(season_wins, need), "max": maxi(1, need)}
	if unlock.begins_with("games:"):
		var need := int(unlock.get_slice(":", 1))
		return {"value": mini(maxi(season_games, regular_games), need), "max": maxi(1, need)}
	if unlock == "champion:SBL":
		return {"value": 1 if bool(championships.get("SBL", false)) else 0, "max": 1}
	if unlock == "league:PLG":
		return {"value": 1 if league_open("PLG") else 0, "max": 1}
	if unlock == "league:TPBL":
		return {"value": 1 if (league_open("TPBL") or current_league == "TPBL") else 0, "max": 1}
	if unlock == "top2:pro":
		return {"value": 1 if pro_top2 else 0, "max": 1}
	if unlock == "start":
		return {"value": 1, "max": 1}
	return {"value": 0, "max": 1}

func locked_tactics() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for kind in ["offense", "defense"]:
		for item in tactic_catalog(kind):
			if not (item is Dictionary):
				continue
			var tactic_id := str(item.get("id", ""))
			if tactic_unlocked_now(tactic_id, kind == "offense"):
				continue
			var row: Dictionary = item.duplicate(true)
			row["kind"] = "進攻" if kind == "offense" else "防守"
			row["hint"] = tactic_unlock_hint(str(item.get("unlock", "")))
			row["progress"] = tactic_unlock_progress(str(item.get("unlock", "")))
			rows.append(row)
	return rows

func sbl_star_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for team in league_teams:
		if str(team.get("league", "")) != "SBL":
			continue
		var best: Dictionary = {}
		var best_ovr := -1
		for raw in team.get("players", []):
			if not (raw is Dictionary):
				continue
			var card := to_game_player(raw)
			var ovr := int(card.get("ovr", 70))
			if ovr > best_ovr:
				best_ovr = ovr
				best = card
		if not best.is_empty():
			pool.append(best)
	pool.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("ovr", 70)) > int(b.get("ovr", 70)))
	return pool

func merge_public_stats(player: Dictionary) -> Dictionary:
	if bool(player.get("draft_2026", false)):
		return player
	var player_name := str(player.get("name", ""))
	for raw in public_players:
		if str(raw.get("name", "")) == player_name:
			for key in ["ppg", "rpg", "apg", "fg3_pct", "fg2_pct", "games", "team"]:
				if not player.has(key) or float(player.get(key, 0.0)) == 0.0:
					player[key] = raw.get(key, player.get(key, 0))
			if str(player.get("origin_team_id", "")).is_empty():
				player["origin_team_id"] = team_id_from_display_name(str(raw.get("team", "")))
			break
	return player

func weekly_stat_line(player: Dictionary) -> String:
	var ppg := float(player.get("ppg", 0.0))
	var apg := float(player.get("apg", 0.0))
	var rpg := float(player.get("rpg", 0.0))
	if ppg <= 0.1 and apg <= 0.1 and rpg <= 0.1:
		return lineup_fit_line(player)
	return "這季數據：%.1f 分 / %.1f 籃板 / %.1f 助攻" % [ppg, rpg, apg]

func lineup_fit_line(player: Dictionary) -> String:
	var pos := str(player.get("pos", player.get("position", "SG")))
	var skill := str(player.get("skill_name", "即戰力"))
	var have := false
	for item in team_players:
		if str(item.get("pos", item.get("position", ""))) == pos:
			have = true
			break
	if not have or team_players.is_empty():
		return "適合當 %s 核心 · %s" % [pos, skill]
	return "適合補 %s / %s" % [pos, skill]

func ovr_tier_key(ovr: int) -> String:
	# 金卡不走 OVR，只給黃金世代老將（見 player_tier_key）。
	if ovr >= 86:
		return "purple"
	if ovr >= 81:
		return "red"
	if ovr >= 76:
		return "blue"
	if ovr >= 71:
		return "green"
	return "cyan"

func player_tier_key(player: Dictionary) -> String:
	if bool(player.get("locked_prize", false)) or str(player.get("tier", "")) == "DIAMOND":
		return "diamond"
	if is_veteran_player(player):
		return "gold"
	return ovr_tier_key(int(player.get("ovr", 65)))

func player_frame_color(player: Dictionary) -> Color:
	return tier_color(player_tier_key(player))

func player_skill_unlocked(player: Dictionary) -> bool:
	# 紫卡、黃金卡與鑽石卡保留原有技能規則；一般卡必須完成特訓 +5。
	var tier := player_tier_key(player)
	if tier in ["purple", "gold", "diamond"]:
		return true
	return int(player.get("training_sessions", 0)) >= TRAINING_MAX_SESSIONS

func ovr_frame_color(ovr: int) -> Color:
	return tier_color(ovr_tier_key(ovr))

func closer_player() -> Dictionary:
	if team_players.is_empty():
		return {}
	if not closer_name.is_empty():
		for player in team_players:
			if str(player.get("name", "")) == closer_name:
				return player
	var best: Dictionary = team_players[0]
	var score := -1.0
	for player in team_players:
		var skill := str(player.get("skill_id", ""))
		var value := float(player.get("ovr", 70)) + float(player.get("ppg", 0.0))
		if skill in ["clutch", "volume_scorer", "floor_general"]:
			value += 6.0
		if value > score:
			score = value
			best = player
	if closer_name.is_empty():
		closer_name = str(best.get("name", ""))
	return best

func season_phase_label() -> String:
	if season_phase in ["playin", "semifinal", "final"] and not playoff_state.is_empty():
		return playoff_series_line()
	match season_phase:
		"semifinal": return "四強"
		"final": return "冠軍戰"
		"champion": return "衛冕"
		"offseason": return "休賽季"
		_:
			var total := regular_season_length()
			if season_games >= total:
				return "例行賽 %d／%d 已打完" % [total, total]
			return "例行賽 下一場 %d／%d" % [clampi(schedule_index + 1, 1, total), total]

func can_sign_player(raw: Dictionary, from_vault := false) -> String:
	if roster_has_player(raw) or (not from_vault and inventory_has_player(raw)):
		return "這名球員已經有了，不會發第二張卡"
	if player_in_other_team(raw):
		return "這名球員已登錄在其他隊伍，不能重複使用"
	if team_players.size() >= roster_limit():
		return "最多 12 人，多的放保管箱"
	if is_veteran_player(raw) and veteran_count() >= 1:
		return "一隊只能有一名黃金世代老將。先釋出或交易現有老將再簽。"
	if is_foreigner(raw) and foreigner_count() >= foreigner_limit():
		return "%s。目前外援 %d／%d。" % [foreigner_rule_line(), foreigner_count(), foreigner_limit()]
	if is_foreign_student(raw) and foreign_student_count() >= foreign_student_limit():
		return "%s。目前外籍生 %d／%d。" % [foreign_student_rule_line(), foreign_student_count(), foreign_student_limit()]
	var salary := published_salary(raw)
	if roster_salary() + salary > salary_cap:
		return "簽入後超出薪資帽 $%d 萬（$%d / $%d 萬）。黃金不能拿來墊薪資。" % [roster_salary() + salary - salary_cap, roster_salary() + salary, salary_cap]
	return ""

func can_replace_trade_player(raw: Dictionary, outgoing_indices: Array) -> String:
	if team_has_player(raw):
		return "這名球員已經有了，不能再拿一張"
	if outgoing_indices.is_empty():
		return "請先選至少一名我方球員"
	var leaving: Dictionary = {}
	for idx in outgoing_indices:
		var index := int(idx)
		if index < 0 or index >= team_players.size():
			return "請重新選擇我方球員"
		leaving[index] = true
		var outgoing: Dictionary = team_players[index]
		if is_veteran_player(outgoing) or is_locked_prize(outgoing):
			return "黃金卡與鑽石卡不能作為交易籌碼"
	var after := team_players.size() - leaving.size() + 1
	if after < minimum_roster_to_play():
		return "交易後至少要留 7 人，請少選幾名我方球員"
	var base_salary := roster_salary()
	for index in leaving.keys():
		base_salary -= published_salary(team_players[int(index)])
	var veterans := 0
	var foreigners := 0
	var students := 0
	for i in team_players.size():
		if leaving.has(i):
			continue
		var player: Dictionary = team_players[i]
		if is_veteran_player(player):
			veterans += 1
		if is_foreigner(player):
			foreigners += 1
		if is_foreign_student(player):
			students += 1
	if is_veteran_player(raw) and veterans >= 1:
		return "一隊只能有一名黃金世代老將"
	if is_foreigner(raw) and foreigners >= foreigner_limit():
		return "%s。目前外援 %d／%d。" % [foreigner_rule_line(), foreigners, foreigner_limit()]
	if is_foreign_student(raw) and students >= foreign_student_limit():
		return "%s。目前外籍生 %d／%d。" % [foreign_student_rule_line(), students, foreign_student_limit()]
	var salary := published_salary(raw)
	if base_salary + salary > salary_cap:
		return "換入後超出薪資帽 $%d 萬。" % (base_salary + salary - salary_cap)
	return ""

func try_purchase_twd(sku: String) -> void:
	show_iap_sheet(sku)

func iap_product(sku: String) -> Dictionary:
	if sku == "monthly_pass":
		return {"title": "主場應援月卡", "price": "NT$190", "store_id": "tb_monthly_pass", "note": "立即獲得黃金 400，之後 30 天每日黃金 50；漏領可累積。附月影雲海限定球場，可永久自由切換。"}
	var gold_bundles := {
		"gold_300": ["300 黃金", "NT$30", "tb_gold_300", 300],
		"gold_900": ["900 黃金", "NT$90", "tb_gold_900", 900],
		"gold_1900": ["1,900 黃金", "NT$190", "tb_gold_1900", 1900],
		"gold_4900": ["4,900 黃金", "NT$490", "tb_gold_4900", 4900],
		"gold_9900": ["9,900 黃金", "NT$990", "tb_gold_9900", 9900],
	}
	if gold_bundles.has(sku):
		var bundle: Array = gold_bundles[sku]
		return {"title": bundle[0], "price": bundle[1], "store_id": bundle[2], "gold_amount": bundle[3], "note": "固定匯率 NT$1＝10 黃金；完成平台付款後立即入帳。"}
	if sku == "extra_save":
		return {"title": "再加一格存檔", "price": "NT$100", "store_id": "tb_extra_save", "note": "一次買一格，帳號最多 10 格。現在 %d／10。" % max_save_slots()}
	if sku == "easl":
		return {"title": "東超／BCL 通行證", "price": "NT$100", "store_id": "tb_easl", "note": "PLG 或 TPBL 前二才能買。東超與 BCL 一起解鎖。拿到冠軍送劉錚鑽石卡。"}
	if sku == "jones":
		return {"title": "瓊斯盃 2026", "price": "NT$60", "store_id": "tb_jones", "note": "PLG 或 TPBL 前二才能買。場次較少，打完可免費再挑戰。拿到冠軍送賀博鑽石卡。"}
	return {"title": "中華隊／世界盃資格賽", "price": "NT$100", "store_id": "tb_national", "note": "PLG 或 TPBL 前二才能買。NT$100 解鎖本存檔世界盃資格賽，拿到冠軍送陳盈駿鑽石卡。"}

func iap_store_ready() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling") or Engine.has_singleton("InAppStore")

func show_iap_sheet(sku: String) -> void:
	iap_pending_sku = sku
	var product := iap_product(sku)
	var content := begin_screen("商店", "%s · %s" % [product.get("title", "商品"), product.get("price", "NT$100")], 0, false)
	content.add_child(callout("平台內購", "黃金、30 日月卡、存檔格與額外賽事。", GOLD))
	content.add_child(label(str(product.get("note", "")), 14, TEXT))
	var price := str(product.get("price", "NT$100"))
	if iap_store_ready():
		content.add_child(action_button("前往購買 %s" % price, ORANGE, func(): start_native_iap(sku), Vector2(0, 52)))
		content.add_child(action_button("恢復購買", CYAN, func(): restore_iap(), Vector2(0, 48)))
	elif OS.has_feature("editor") or OS.get_environment("TB_PLAYTEST") == "1" or OS.get_environment("TB_IAP_SANDBOX") == "1":
		content.add_child(label("編輯器／沙盒：確認後寫入本機憑證，方便你測流程。", 12, MUTED))
		content.add_child(action_button("沙盒完成 %s" % price, ORANGE, func(): complete_purchase(sku), Vector2(0, 52)))
	else:
		content.add_child(label("平台商店尚未連線，本次不會扣款。請先完成 StoreKit／Google Play Billing 商品與外掛設定。", 13, MUTED))
		content.add_child(action_button("恢復已買憑證", CYAN, func(): restore_iap(), Vector2(0, 48)))
	content.add_child(action_button("取消", Color("254e6b"), func():
		pending_enter_league = ""
		if sku in ["national", "jones", "easl"]:
			show_extra_events()
		elif sku == "extra_save":
			show_save_slots()
		else:
			show_store_hub()
	, Vector2(0, 48)))

func start_native_iap(sku: String) -> void:
	if not iap_pending_sku.is_empty() and iap_pending_sku != sku:
		flash_notice("請先完成目前的商店操作")
		return
	var product := iap_product(sku)
	var store_id := str(product.get("store_id", sku))
	if Engine.has_singleton("GodotGooglePlayBilling"):
		var billing = Engine.get_singleton("GodotGooglePlayBilling")
		if billing.has_method("purchase"):
			billing.purchase(store_id)
			flash_notice("已開啟 %s 內購視窗" % product.get("price", "商店"))
			return
	if Engine.has_singleton("InAppStore"):
		var store = Engine.get_singleton("InAppStore")
		if store.has_method("purchase"):
			store.purchase({"product_id": store_id})
			flash_notice("已開啟 %s 內購視窗" % product.get("price", "商店"))
			return
	flash_notice("商店外掛沒回應，尚未扣款")

func restore_iap() -> void:
	if bool(iap_receipts.get("extra_save", false)):
		extra_save_unlocked = true
	if bool(iap_receipts.get("national_%d" % active_save_slot, false)):
		national_unlocked = true
	if bool(iap_receipts.get("easl", false)):
		easl_pass = true
	if bool(iap_receipts.get("jones", false)):
		jones_pass = true
	if bool(iap_receipts.get("monthly_pass", false)):
		monthly_pass_active = true
		if not store_cosmetics_owned.has("arena_monthly"):
			store_cosmetics_owned.append("arena_monthly")
	save_account()
	flash_notice("已依本機／雲端憑證恢復購買")
	show_store_hub()

func iap_event_matches_pending(event: Dictionary) -> bool:
	return not iap_pending_sku.is_empty() and str(event.get("type", "")) == "purchase" and str(event.get("result", "")) == "ok" and str(event.get("product_id", "")) == str(iap_product(iap_pending_sku).get("store_id", ""))

func poll_native_iap() -> void:
	if iap_pending_sku.is_empty() or not iap_store_ready():
		return
	if Engine.has_singleton("InAppStore"):
		var store = Engine.get_singleton("InAppStore")
		if store.has_method("get_pending_event_count") and int(store.get_pending_event_count()) > 0:
			var event = store.pop_pending_event()
			if not (event is Dictionary):
				return
			if iap_event_matches_pending(event):
				var product_id := str(event.product_id)
				complete_purchase(iap_pending_sku)
				if store.has_method("finish_transaction"):
					store.finish_transaction(product_id)
			elif str(event.get("type", "")) == "purchase" and str(event.get("result", "")) == "error":
				iap_pending_sku = ""
				flash_notice("購買未完成，沒有新增付費內容")

func complete_purchase(sku: String) -> void:
	if sku == "monthly_pass":
		var first_activation := not bool(iap_receipts.get("monthly_pass", false))
		monthly_pass_active = true
		iap_receipts["monthly_pass"] = true
		if first_activation:
			gold += 400
			if not store_cosmetics_owned.has("arena_monthly"):
				store_cosmetics_owned.append("arena_monthly")
		iap_pending_sku = ""
		save_account()
		save_game()
		show_daily_tasks()
		queue_purchase_success("主場應援月卡", "黃金 +400，月影雲海球場已永久解鎖")
		return
	if sku.begins_with("gold_"):
		var amount := int(iap_product(sku).get("gold_amount", 0))
		if amount <= 0:
			flash_notice("黃金商品資料錯誤，沒有扣款")
			return
		gold += amount
		iap_pending_sku = ""
		save_game()
		show_store_hub()
		queue_purchase_success(str(iap_product(sku).get("title", "黃金")), "黃金 +%s 已入帳" % resource_display_number(amount))
		return
	if sku == "extra_save":
		if extra_slots_left() <= 0:
			flash_notice("存檔格已經 10 格")
			show_save_slots()
			return
		extra_save_bought += 1
		extra_save_unlocked = true
		iap_receipts["extra_save"] = true
		iap_receipts["extra_save_count"] = extra_save_bought
		iap_pending_sku = ""
		save_account()
		show_save_slots()
		queue_purchase_success("增加存檔格", "目前 %d／10 格" % max_save_slots())
		return
	if sku == "easl":
		easl_pass = true
		iap_receipts["easl"] = true
		iap_pending_sku = ""
		save_account()
		save_game()
		pending_enter_league = ""
		show_extra_event("easl")
		queue_purchase_success("東超／BCL 通行證", "賽事已永久解鎖")
		return
	if sku == "jones":
		jones_pass = true
		iap_receipts["jones"] = true
		iap_pending_sku = ""
		save_account()
		save_game()
		show_extra_event("jones")
		queue_purchase_success("瓊斯盃 2026", "賽事已永久解鎖")
		return
	if sku == "national":
		national_unlocked = true
		iap_receipts["national_%d" % active_save_slot] = true
		iap_pending_sku = ""
		save_game()
		show_extra_event("wcq")
		queue_purchase_success("世界盃資格賽", "本存檔已永久解鎖")
		return

func store_products() -> Array[Dictionary]:
	return [
		{"id":"arena_taipei", "title":"台北雨夜河濱", "category":"球場", "price":"300 黃金", "gold":300, "art":"res://assets/art/arenas/taiwan/taipei_riverside.png", "description":"雨停後的河濱最會留人。遠方城市燈亮了，這一球還不能散。", "note":"台灣城市系列 · 戶外", "theme":"台北雨夜河濱"},
		{"id":"arena_new_taipei", "title":"新北籃球聖殿", "category":"球場", "price":"300 黃金", "gold":300, "art":"res://assets/art/arenas/taiwan/new_taipei_xinzhuang.png", "description":"看台很近、聲音很滿。踏進這裡，連熱身球都像決勝球。", "note":"台灣城市系列 · 室內", "theme":"新北籃球聖殿"},
		{"id":"arena_taichung", "title":"台中弧光主場", "category":"球場", "price":"300 黃金", "gold":300, "art":"res://assets/art/arenas/taiwan/taichung_arc.png", "description":"木質弧頂把歡呼收得剛剛好，中場一抬頭就是城市綠意。", "note":"台灣城市系列 · 室內", "theme":"台中弧光主場"},
		{"id":"arena_tainan", "title":"台南古都夜場", "category":"球場", "price":"300 黃金", "gold":300, "art":"res://assets/art/arenas/taiwan/tainan_oldtown.png", "description":"紅磚、老樹、晚風。輸的人請下一攤，贏的人留下來再一場。", "note":"台灣城市系列 · 戶外", "theme":"台南古都夜場"},
		{"id":"arena_kaohsiung", "title":"高雄港灣夕照", "category":"球場", "price":"300 黃金", "gold":300, "art":"res://assets/art/arenas/taiwan/kaohsiung_harbor.png", "description":"海風會干擾投籃，夕陽不會。港邊燈一亮，就是南方主場時間。", "note":"台灣城市系列 · 戶外", "theme":"高雄港灣夕照"},
		{"id":"arena_hualien", "title":"花蓮山海晨光", "category":"球場", "price":"300 黃金", "gold":300, "art":"res://assets/art/arenas/taiwan/hualien_coast.png", "description":"左手是山、右手是海。早起投進第一球，今天就不會太差。", "note":"台灣城市系列 · 戶外", "theme":"花蓮山海晨光"},
		{"id":"arena_champion", "title":"冠軍金色球場", "category":"球場", "price":"500 黃金", "gold":500, "art":"res://assets/art/arena_playoff.png", "description":"聚光燈只照向球場中央。今晚，獎盃和壓力都是真的。", "note":"虛擬球場 · 永久解鎖", "theme":"冠軍金色主場"},
		{"id":"arena_neon", "title":"霓虹球場", "category":"球場", "price":"500 黃金", "gold":500, "art":"res://assets/art/arenas/cyberpunk_arena_base.png", "description":"藍紫燈線沿著三分線醒來，適合把比賽打得比夜還晚。", "note":"虛擬球場 · 永久解鎖", "theme":"賽博龐克主場"},
		{"id":"arena_night", "title":"夜場靛藍", "category":"球場", "price":"500 黃金", "gold":500, "art":"res://assets/art/arena_night.png", "description":"把觀眾席壓暗，只留下籃框和下一次進攻。", "note":"虛擬球場 · 永久解鎖", "theme":"夜場靛藍"},
		{"id":"arena_monthly", "title":"月影雲海球場", "category":"球場", "price":"月卡限定", "gold":0, "art":"res://assets/art/arenas/monthly_moon.png", "description":"雲海壓低喧鬧，月光替三分線描金。購買月卡後永久保留，可自由切換。", "note":"主場應援月卡限定", "theme":"月影雲海球場"},
		{"id":"locker_wood", "title":"木質職業更衣室", "category":"更衣室", "price":"300 黃金", "gold":300, "art":"res://assets/art/locker_rooms/pro_wood.png", "description":"木櫃、皮椅、乾淨的戰術牆。沒有藉口，只剩上場前的安靜。", "note":"更衣室背景 · 永久解鎖", "locker":"木質職業更衣室"},
		{"id":"locker_champion", "title":"黑金冠軍更衣室", "category":"更衣室", "price":"500 黃金", "gold":500, "art":"res://assets/art/locker_rooms/champion_black_gold.png", "description":"獎盃放在正中央提醒所有人：拿過一次，不代表已經足夠。", "note":"更衣室背景 · 永久解鎖", "locker":"黑金冠軍更衣室"},
		{"id":"locker_neon", "title":"霓虹科技更衣室", "category":"更衣室", "price":"600 黃金", "gold":600, "art":"res://assets/art/locker_rooms/neon_tech.png", "description":"燈線亮起、戰術上牆。這裡不像休息室，更像下一場的控制中心。", "note":"更衣室背景 · 永久解鎖", "locker":"霓虹科技更衣室"},
		{"id":"locker_retro", "title":"復古台籃更衣室", "category":"更衣室", "price":"700 黃金", "gold":700, "art":"res://assets/art/locker_rooms/retro_taiwan.png", "description":"磨亮的磨石子地板和老風扇，裝著一整代球迷熟悉的夏天。", "note":"更衣室背景 · 永久解鎖", "locker":"復古台籃更衣室"},
		{"id":"vault_plus_10", "title":"保管箱擴充 +10", "category":"便利功能", "price":"300 黃金", "gold":300, "art":"res://assets/ui/icons/nav_vault.png", "description":"初始容量 20 張，每次永久增加 10 格。收藏可以慢慢長大，不必急著放棄誰。", "note":"可重複購買", "utility":"vault"},
		{"id":"save_plus_1", "title":"增加存檔格", "category":"便利功能", "price":"1,000 黃金", "gold":1000, "art":"res://assets/ui/store/save_slot.png", "description":"永久增加一個獨立球隊存檔，最多 10 格。每一格都是另一段總管生涯。", "note":"帳號功能", "utility":"save"},
		{"id":"second_team", "title":"解鎖第二隊伍", "category":"便利功能", "price":"300 黃金", "gold":300, "art":"res://assets/art/lobby/roster.png", "description":"同一存檔建立第二支球隊，首頁可一鍵切換，兩隊名單與生涯各自保存。", "note":"永久解鎖 · 可切換", "utility":"team_two"},
		{"id":"event_jones", "title":"瓊斯盃", "category":"賽事", "price":"600 黃金", "gold":600, "art":"res://assets/ui/store/jones.png", "description":"短期盃賽節奏快、壓力直接。挑戰專屬獎盃、紀錄、新聞事件與賽事獎勵。", "note":"永久賽事擴充", "event":"jones"},
		{"id":"event_easl", "title":"東超／BCL", "category":"賽事", "price":"900 黃金", "gold":900, "art":"res://assets/ui/store/easl.png", "description":"跨國客場、陌生節奏、三場定生死。包含專屬獎盃、紀錄與特殊新聞。", "note":"兩項賽事一起永久解鎖", "event":"easl"},
		{"id":"event_wcq", "title":"世界盃資格賽", "category":"賽事", "price":"1,200 黃金", "gold":1200, "art":"res://assets/ui/store/national.png", "description":"選出中華隊名單，走過資格賽。勝利會留下國家隊紀錄與專屬成就。", "note":"永久賽事擴充", "event":"wcq"},
		{"id":"event_bundle", "title":"國際賽事完整包", "category":"賽事", "price":"2,200 黃金", "gold":2200, "art":"res://assets/art/activity/activity_vs_hero.png", "description":"一次解鎖瓊斯盃、東超／BCL與世界盃資格賽，三條故事線都保留重玩空間。", "note":"組合價 · 永久解鎖", "event":"bundle"},
		{"id":"monthly_pass", "title":"主場應援月卡", "category":"黃金", "price":"NT$190", "gold":-1, "art":"res://assets/art/arenas/monthly_moon.png", "description":"立即 400 黃金，之後 30 天每日 50 黃金；漏領可累積。另送月影雲海球場，可自由切換。", "note":"總計 1,900 黃金 · 限定球場永久保留", "sku":"monthly_pass"},
		{"id":"gold_300", "title":"300 黃金", "category":"黃金", "price":"NT$30", "gold":-1, "art":"res://assets/ui/hud/gold_coin.png", "description":"小額補充，匯率固定 NT$1＝10 黃金。", "note":"平台內購", "sku":"gold_300"},
		{"id":"gold_900", "title":"900 黃金", "category":"黃金", "price":"NT$90", "gold":-1, "art":"res://assets/ui/hud/gold_coin.png", "description":"需要一座球場，或替更衣室換個氣氛。", "note":"平台內購", "sku":"gold_900"},
		{"id":"gold_1900", "title":"1,900 黃金", "category":"黃金", "price":"NT$190", "gold":-1, "art":"res://assets/ui/hud/gold_coin.png", "description":"固定 1：10，不用猜哪一包才划算。", "note":"平台內購", "sku":"gold_1900"},
		{"id":"gold_4900", "title":"4,900 黃金", "category":"黃金", "price":"NT$490", "gold":-1, "art":"res://assets/ui/hud/gold_coin.png", "description":"適合一次收藏多座城市球場。", "note":"平台內購", "sku":"gold_4900"},
		{"id":"gold_9900", "title":"9,900 黃金", "category":"黃金", "price":"NT$990", "gold":-1, "art":"res://assets/ui/hud/gold_coin.png", "description":"最高額固定匯率方案，不製造假折扣。", "note":"平台內購", "sku":"gold_9900"},
	]

func store_visible_products(category: String) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for product in store_products():
		if category == "精選" and str(product.id) in ["arena_taipei", "arena_tainan", "arena_champion", "monthly_pass"]:
			visible.append(product)
		elif str(product.category) == category:
			visible.append(product)
	return visible

func store_product_by_id(product_id: String) -> Dictionary:
	for product in store_products():
		if str(product.id) == product_id:
			return product
	return store_products()[0]

func store_cosmetic_owned(product: Dictionary) -> bool:
	return store_cosmetics_owned.has(str(product.get("id", "")))

func training_glow_unlocked() -> bool:
	for player in team_players:
		if int(player.get("training_sessions", 0)) >= TRAINING_MAX_SESSIONS:
			return true
	return false

func store_product_status(product: Dictionary) -> String:
	var product_id := str(product.get("id", ""))
	if product.has("theme"):
		if store_cosmetic_owned(product):
			return "使用中" if supporter_theme == str(product.theme) else "已永久解鎖"
		return "尚未擁有"
	if product.has("locker"):
		if store_cosmetic_owned(product):
			return "使用中" if locker_room_theme == str(product.locker) else "已永久解鎖"
		return "尚未擁有"
	if product_id == "vault_plus_10":
		return "目前 %d 格" % vault_capacity()
	if product_id == "save_plus_1":
		return "已滿 10 格" if extra_slots_left() <= 0 else "目前 %d／10 格" % max_save_slots()
	if product_id == "second_team":
		return "已永久解鎖" if second_team_unlocked else "目前只有第一隊"
	if product.has("event"):
		var event_id := str(product.event)
		if event_id == "bundle":
			return "已全部解鎖" if easl_pass and jones_pass and national_unlocked else "三項賽事組合價"
		return "已永久解鎖" if extra_event_owned(event_id) else "尚未解鎖"
	if product_id == "monthly_pass":
		return "已開通" if monthly_pass_active else "30 天應援內容"
	if product.has("sku"):
		return "NT$1＝10 黃金"
	return "可購買"

func select_store_product(category: String, product_id: String) -> void:
	store_category = category
	store_selected_product = product_id
	show_store_hub()

func activate_store_product(product: Dictionary) -> void:
	var product_id := str(product.get("id", ""))
	if product.has("sku"):
		var sku := str(product.sku)
		if sku == "monthly_pass" and monthly_pass_active:
			show_daily_tasks()
		else:
			show_iap_sheet(sku)
		return
	if product.has("theme"):
		if product_id == "arena_monthly" and not store_cosmetic_owned(product):
			select_store_product("黃金", "monthly_pass")
			flash_notice("月影雲海球場隨主場應援月卡解鎖")
			return
		if store_cosmetic_owned(product):
			supporter_theme = str(product.theme)
			home_environment_mode = "arena"
			save_game()
			flash_notice("已套用「%s」" % product.title)
			show_store_hub()
			return
		var price := int(product.get("gold", 0))
		if gold < price:
			flash_notice("黃金不足：還差 %d 黃金" % (price - gold))
			return
		gold -= price
		store_cosmetics_owned.append(product_id)
		supporter_theme = str(product.theme)
		home_environment_mode = "arena"
		save_game()
		show_store_hub()
		queue_purchase_success(str(product.title), "已永久解鎖並套用到主場")
		return
	if product.has("locker"):
		if store_cosmetic_owned(product):
			locker_room_theme = str(product.locker)
			home_environment_mode = "locker"
			save_game()
			flash_notice("已套用「%s」" % product.title)
			show_store_hub()
			return
		if not spend_store_gold(product):
			return
		store_cosmetics_owned.append(product_id)
		locker_room_theme = str(product.locker)
		home_environment_mode = "locker"
		save_game()
		show_store_hub()
		queue_purchase_success(str(product.title), "已永久解鎖並套用到更衣室")
		return
	if product_id == "vault_plus_10":
		if not spend_store_gold(product):
			return
		vault_capacity_bonus += 10
		save_game()
		show_store_hub()
		queue_purchase_success("保管箱擴充 +10", "目前容量 %d 格" % vault_capacity())
		return
	if product_id == "save_plus_1":
		if extra_slots_left() <= 0:
			flash_notice("存檔格已經 10 格")
			return
		if not spend_store_gold(product):
			return
		extra_save_bought += 1
		extra_save_unlocked = true
		save_account()
		save_game()
		show_store_hub()
		queue_purchase_success("增加存檔格", "目前 %d／10 格" % max_save_slots())
		return
	if product_id == "second_team":
		if second_team_unlocked:
			flash_notice("第二隊伍已經解鎖")
			return
		if not spend_store_gold(product):
			return
		second_team_unlocked = true
		save_game()
		show_store_hub()
		queue_purchase_success("第二隊伍", "已永久解鎖，可從首頁切換")
		return
	if product.has("event"):
		var event_id := str(product.event)
		if (event_id == "bundle" and easl_pass and jones_pass and national_unlocked) or (event_id != "bundle" and extra_event_owned(event_id)):
			show_extra_events()
			return
		if not spend_store_gold(product):
			return
		if event_id in ["easl", "bundle"]: easl_pass = true
		if event_id in ["jones", "bundle"]: jones_pass = true
		if event_id in ["wcq", "bundle"]: national_unlocked = true
		save_account()
		save_game()
		show_store_hub()
		queue_purchase_success(str(product.title), "賽事內容已永久解鎖")

func spend_store_gold(product: Dictionary) -> bool:
	var price := int(product.get("gold", 0))
	if gold < price:
		flash_notice("黃金不足：還差 %d 黃金" % (price - gold))
		return false
	gold -= price
	return true

func extra_event_owned(event_id: String) -> bool:
	match event_id:
		"easl": return easl_pass
		"jones": return jones_pass
		"wcq": return national_unlocked
		_: return false

func vault_capacity() -> int:
	return 20 + vault_capacity_bonus

func store_category_button(caption: String, selected: bool) -> Button:
	var icons := {"精選":"★", "球場":"▣", "更衣室":"⌂", "便利功能":"◆", "賽事":"♜", "黃金":"●"}
	var narrow := usable_view().x < 720.0
	var button := action_button("%s  %s" % [icons.get(caption, "•"), caption], Color("101923e8"), func():
		var products := store_visible_products(caption)
		var first_id := str(products[0].id) if not products.is_empty() else "arena_taipei"
		select_store_product(caption, first_id)
	, Vector2(92 if narrow else (112 if is_handheld() else 142), 38 if narrow else 39))
	button.add_theme_font_size_override("font_size", 12 if narrow else 14)
	button.add_theme_stylebox_override("normal", panel_style(Color("2b2413e8") if selected else Color("0b1420e8"), GOLD if selected else Color("405064"), 10, 2 if selected else 1))
	return button

func store_product_card(product: Dictionary, selected: bool) -> Control:
	var shell := PanelContainer.new()
	shell.name = "StoreProduct_" + str(product.id)
	shell.custom_minimum_size = Vector2(142 if is_handheld() else 184, 120 if compact_phone() else 184)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.clip_contents = true
	shell.add_theme_stylebox_override("panel", panel_style(Color("08121ef2"), GOLD if selected else Color("445466"), 13, 2 if selected else 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	shell.add_child(padded(box, 6))
	var art := TextureRect.new()
	art.texture = load_png_tex(str(product.art))
	art.custom_minimum_size = Vector2(0, 63 if compact_phone() else 112)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if str(product.category) == "球場" else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	box.add_child(fit_label(str(product.title), 14, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(fit_label(str(product.price), 13, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var hit := hub_tile_hit(GOLD, selected, func(): select_store_product(store_category, str(product.id)))
	shell.add_child(hit)
	bind_press_juice(shell, hit)
	return shell

func store_detail_panel(product: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "StoreProductDetail"
	panel.custom_minimum_size = Vector2(230 if is_handheld() else 310, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("07111df2"), Color("ba974799"), 14, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(padded(box, 10))
	var art := TextureRect.new()
	art.texture = load_png_tex(str(product.art))
	art.custom_minimum_size = Vector2(0, 70 if compact_phone() else 130)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if str(product.category) == "球場" else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	box.add_child(label(str(product.title), 19, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(wrap_label(str(product.description), 12, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(fit_label(store_product_status(product), 12, CYAN if store_product_status(product).contains("已") else GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(fit_label(str(product.note), 11, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	var action_text := "購買 · %s" % str(product.price)
	if product.has("theme") and store_cosmetic_owned(product):
		action_text = "使用中" if supporter_theme == str(product.theme) else "套用"
	elif product.has("locker") and store_cosmetic_owned(product):
		action_text = "使用中" if locker_room_theme == str(product.locker) else "套用"
	elif str(product.id) == "second_team" and second_team_unlocked:
		action_text = "已解鎖"
	elif product.has("event") and str(product.event) != "bundle" and extra_event_owned(str(product.event)):
		action_text = "前往賽事"
	elif str(product.id) == "monthly_pass" and monthly_pass_active:
		action_text = "前往領取"
	var buy := gold_action_button(action_text, func(): activate_store_product(product), Vector2(0, 48))
	buy.name = "StorePurchaseButton"
	buy.disabled = str(product.id) == "second_team" and second_team_unlocked
	box.add_child(buy)
	return panel

func show_store_hub() -> void:
	active_menu = "store"
	var visible := store_visible_products(store_category)
	if visible.is_empty():
		store_category = "精選"
		visible = store_visible_products(store_category)
	if not visible.any(func(product: Dictionary): return str(product.id) == store_selected_product):
		store_selected_product = str(visible[0].id)
	var selected := store_product_by_id(store_selected_product)
	var content := begin_screen("商店", "圖案、內容與價格一次看清楚；外觀商品不影響勝負。", 4, true, false)
	var wide_store := usable_view().x >= 540.0
	var layout: BoxContainer = HBoxContainer.new() if wide_store else VBoxContainer.new()
	layout.name = "StoreLayout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	content.add_child(layout)
	var categories: BoxContainer = VBoxContainer.new() if wide_store else HBoxContainer.new()
	categories.name = "StoreCategories"
	categories.custom_minimum_size.x = ((176 if usable_view().x >= 1000.0 else 112) if is_handheld() else 168) if wide_store else 0
	categories.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if wide_store else Control.SIZE_EXPAND_FILL
	categories.add_theme_constant_override("separation", 6)
	layout.add_child(categories)
	for category in ["精選", "球場", "更衣室", "便利功能", "賽事", "黃金"]:
		categories.add_child(store_category_button(category, store_category == category))
	var products_and_detail := HBoxContainer.new()
	products_and_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	products_and_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	products_and_detail.add_theme_constant_override("separation", 8)
	layout.add_child(products_and_detail)
	var product_scroll := ScrollContainer.new()
	product_scroll.name = "StoreProductScroll"
	product_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	product_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	product_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	products_and_detail.add_child(product_scroll)
	var grid := GridContainer.new()
	grid.name = "StoreProductGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	product_scroll.add_child(grid)
	bind_scroll_child_width(product_scroll, grid)
	for product in visible:
		grid.add_child(store_product_card(product, str(product.id) == store_selected_product))
	products_and_detail.add_child(store_detail_panel(selected))

func store_icon_tex(icon_id: String) -> Texture2D:
	return load_png_tex(str(STORE_ICONS.get(icon_id, "")))

func store_square(title: String, price: String, note: String, accent: Color, action: Callable, icon_id := "") -> Control:
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(0, 96 if compact_phone() else 128)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shell.clip_contents = true
	shell.add_theme_stylebox_override("panel", panel_style(Color(0.06, 0.08, 0.12, 0.92), accent.darkened(0.22), 14, 1))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	shell.add_child(padded(box, 6))
	var art := store_icon_tex(icon_id)
	if art != null:
		var glyph := TextureRect.new()
		glyph.texture = art
		glyph.custom_minimum_size = Vector2(28 if compact_phone() else 44, 28 if compact_phone() else 44)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(glyph)
	var title_lab := fit_label(title, 11 if compact_phone() else 14, accent, true, HORIZONTAL_ALIGNMENT_CENTER)
	title_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_lab)
	box.add_child(plain_label(price, 16 if compact_phone() else 18, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	if not note.is_empty():
		var foot := fit_label(note, 10, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
		foot.autowrap_mode = TextServer.AUTOWRAP_OFF
		box.add_child(foot)
	var hit := hub_tile_hit(accent, false, action)
	shell.add_child(hit)
	bind_press_juice(shell, hit)
	return shell

func ensure_referral_code() -> String:
	if not referral_code.is_empty():
		return referral_code
	var seed := "%s-%d-%d" % [OS.get_unique_id(), Time.get_unix_time_from_system(), randi()]
	var n := absi(seed.hash()) % 1679616
	referral_code = "TB%04X" % (n % 65536)
	return referral_code

func referral_link() -> String:
	return "https://tbasket.app/r/%s" % ensure_referral_code()

func referral_board_path() -> String:
	return "user://taiwan_basketball_ref_board.json"

func load_referral_board() -> Dictionary:
	if not FileAccess.file_exists(referral_board_path()):
		return {}
	var file := FileAccess.open(referral_board_path(), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func save_referral_board(board: Dictionary) -> void:
	var file := FileAccess.open(referral_board_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(board))

func grant_referral_slot_once() -> bool:
	if referral_slot_granted:
		return false
	referral_slot_granted = true
	return extra_slots_left() >= 0 and max_save_slots() <= 10

func apply_referral_board() -> void:
	var mine := ensure_referral_code()
	var board := load_referral_board()
	var row = board.get(mine, {})
	if not (row is Dictionary):
		return
	var uses := int(row.get("count", 0))
	if uses > referral_count:
		referral_count = uses
	if uses > 0:
		grant_referral_slot_once()
	if referral_count >= 10:
		grant_hidden_lin_card()

func record_referral_use(host_code: String, guest_code: String) -> void:
	var board := load_referral_board()
	var row: Dictionary = board.get(host_code, {})
	if not (row is Dictionary):
		row = {}
	var used: Array = row.get("used", [])
	if guest_code in used:
		return
	used.append(guest_code)
	row["used"] = used
	row["count"] = used.size()
	board[host_code] = row
	save_referral_board(board)

func show_referral_sheet() -> void:
	active_menu = "more"
	apply_referral_board()
	var content := begin_screen("好友推薦", "雙方輸入後各加一格存檔 · 限一次。推薦 10 人送林書豪隱藏卡", 4)
	var code := ensure_referral_code()
	content.add_child(callout("你的推薦碼", code, GOLD))
	content.add_child(wrap_label("已推薦 %d／10 人。滿 10 人送林書豪 OVR 90 鑽石卡，並加 1000 萬薪資。他算進任何組合，技能是全隊 OVR +1。" % referral_count, 13, MUTED, true))
	content.add_child(action_button("複製推薦碼", CYAN, func():
		DisplayServer.clipboard_set(code)
		flash_notice("已複製推薦碼")
	, Vector2(0, 44)))
	if referral_entered.is_empty():
		content.add_child(label("輸入好友的推薦碼", 16, GOLD, true))
		var field := text_field("例如 TB1A2B", "")
		content.add_child(field)
		content.add_child(gold_action_button("送出推薦碼", func():
			claim_referral_code(field.text)
		, Vector2(0, 48)))
	else:
		content.add_child(callout("已輸入", "你用過 %s。雙方存檔格獎勵限一次。" % referral_entered, GREEN))
	if lin_hidden_granted:
		content.add_child(callout("隱藏卡", "林書豪鑽石卡已在你的名單或收藏。", PURPLE))

func claim_referral_code(raw: String) -> void:
	var code := raw.strip_edges().to_upper().replace(" ", "")
	if code.begins_with("HTTPS://"):
		var slash := code.rfind("/")
		if slash >= 0:
			code = code.substr(slash + 1)
	if not referral_entered.is_empty():
		flash_notice("推薦碼只能用一次")
		return
	if code.is_empty() or not code.begins_with("TB") or code.length() < 5 or code.length() > 12:
		flash_notice("推薦碼格式不對")
		return
	if code == ensure_referral_code():
		flash_notice("不能輸入自己的碼")
		return
	referral_entered = code
	record_referral_use(code, ensure_referral_code())
	grant_referral_slot_once()
	apply_referral_board()
	save_account()
	flash_notice("推薦成功。雙方各加一格存檔（限一次），現在 %d／10。" % max_save_slots())
	show_referral_sheet()

func grant_hidden_lin_card() -> void:
	if lin_hidden_granted:
		return
	lin_hidden_granted = true
	budget_million += 1000
	grant_prize_card("lin")
	save_account()
	save_game()
	flash_notice("推薦 10 人：林書豪隱藏卡 +1000 萬")
	maybe_play_card_reveal()

func show_line_community() -> void:
	active_menu = "more"
	var content := begin_screen("官方社群", "掃描 QR 加入 LINE 討論", 4)
	content.add_child(callout("LINE 社群", "用手機鏡頭或 LINE 掃這個 QR，加入官方討論。電腦版請把遊戲畫面給手機掃。", GREEN))
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", panel_style(Color("f6f8fb"), GOLD, 16, 2))
	content.add_child(frame)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(280, 280)
	art.texture = load_png_tex(LINE_QR_PATH)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(padded(art, 12))
	content.add_child(label("掃不到時，可把這張圖截圖後用 LINE 相簿掃描。", 13, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))

func try_enter_international(code: String) -> void:
	if code not in ["EASL", "BCL"]:
		return
	if not pro_top2:
		flash_notice("PLG 或 TPBL 例行賽前二才能打東超／BCL")
		return
	if not easl_pass:
		pending_enter_league = code
		select_store_product("賽事", "event_easl")
		return
	enter_league(code)

func try_open_national() -> void:
	if not pro_top2:
		flash_notice("PLG 或 TPBL 例行賽前二才能解鎖中華隊")
		show_national_team()
		return
	if not national_unlocked:
		select_store_product("賽事", "event_wcq")
		return
	show_national_team()

func mark_pro_top2_if_earned() -> void:
	if current_league not in ["PLG", "TPBL"]:
		return
	if club_seed() > 2:
		return
	if pro_top2:
		return
	pro_top2 = true
	last_event += " 取得職業聯盟前二資格，可解鎖東超／BCL 與中華隊。"
	push_news("資格：例行賽前二。東超／BCL 通行證 NT$100，中華隊 NT$100。")

func open_offseason(reason: String) -> void:
	season_phase = "offseason"
	last_event = reason

func start_next_season(switch_to: String, bump: bool, skip_draft := false) -> void:
	if draft_eligible() and not bool(draft_state.get("completed", false)) and not remaining_draft_players().is_empty() and not skip_draft:
		show_guide_sheet("本季還沒選秀", "你可以先到市場選秀，或明確略過本季選秀後開始下一季。", CYAN)
		var body := guide_modal.find_child("GuideBody", true, false)
		body.add_child(action_button("先去選秀", CYAN, func(): show_draft_market()))
		body.add_child(action_button("略過選秀，開始下一季", MUTED, func(): start_next_season(switch_to, bump, true)))
		return
	if pending_path == "pro" and switch_to in ["PLG", "TPBL"]:
		if not unlocked_leagues.has(switch_to):
			unlocked_leagues.append(switch_to)
		pending_path = ""
	elif switch_to in ["PLG", "TPBL"] and not unlocked_leagues.has(switch_to):
		if bool(championships.get("SBL", false)):
			unlocked_leagues.append(switch_to)
		else:
			flash_notice("還沒解鎖 %s" % switch_to)
			return
	if bump:
		difficulty_level += 1
	playoff_state.clear()
	draft_state.clear()
	current_league = switch_to
	if switch_to in ["SBL", "PLG", "TPBL"]:
		last_pro_league = switch_to
	apply_salary_cap()
	season_phase = "regular"
	reset_regular_season()
	scout_floor_game = -1
	ensure_season_scout()
	refresh_opponents(true)
	last_event = "新賽季開始：%s。對手戰力難度 %d（每級 +2，最多 +12）。" % [switch_to, difficulty_level]
	save_game()
	show_dashboard()

func show_offseason() -> void:
	active_menu = "more"
	var content := begin_screen("休賽季", "%s · 難度 %d" % [club_name, difficulty_level], 4)
	if draft_eligible():
		content.add_child(action_button("查看本季選秀" if bool(draft_state.get("completed", false)) else "參加本季選秀", CYAN, func(): open_sub(show_offseason, show_draft_market)))
	content.add_child(callout("賽季結束", last_event if not last_event.is_empty() else "選下一季或換聯盟。再打一次難度會提高。", GOLD))
	content.add_child(label("第一次從 SBL 升上 PLG／TPBL 不加難。之後換聯盟或打下一季，對手戰力每級 +2。", 13, MUTED))
	if pro_top2:
		content.add_child(label("已有職業前二資格。東超／BCL 需 NT$100 通行證。", 13, GREEN))
	else:
		content.add_child(label("東超資格：PLG 或 TPBL 例行賽前二。", 13, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	if pending_path == "pro":
		content.add_child(callout("升上職業", "選一條職業聯盟。第一次升上不加難，也不能同時打兩聯盟。", ORANGE))
		row.add_child(action_button("去 PLG", ORANGE, func(): start_next_season("PLG", false), Vector2(0, 50)))
		row.add_child(action_button("去 TPBL", CYAN, func(): start_next_season("TPBL", false), Vector2(0, 50)))
	else:
		var next_league := current_league
		if current_league in ["EASL", "BCL"]:
			next_league = last_pro_league if last_pro_league in ["PLG", "TPBL", "SBL"] else "PLG"
		row.add_child(action_button("下一季 · %s" % next_league, ORANGE, func(code := next_league): start_next_season(code, true), Vector2(0, 50)))
		if current_league in ["PLG", "TPBL"]:
			var other := "TPBL" if current_league == "PLG" else "PLG"
			if league_open(other) or bool(championships.get("SBL", false)) or unlocked_leagues.has(other):
				row.add_child(action_button("換 %s" % other, CYAN, func(code := other): start_next_season(code, true), Vector2(0, 50)))
		if current_league in ["EASL", "BCL"]:
			if unlocked_leagues.has("PLG"):
				row.add_child(action_button("回 PLG", ORANGE, func(): start_next_season("PLG", true), Vector2(0, 50)))
			if unlocked_leagues.has("TPBL"):
				row.add_child(action_button("回 TPBL", CYAN, func(): start_next_season("TPBL", true), Vector2(0, 50)))
		var intl := HBoxContainer.new()
		intl.add_theme_constant_override("separation", 8)
		content.add_child(intl)
		var easl_caption := "去東超（3 場）" if easl_pass else "解鎖東超／BCL · 900 黃金"
		var bcl_caption := "去 BCL（3 場）" if easl_pass else "解鎖東超／BCL · 900 黃金"
		intl.add_child(action_button(easl_caption if pro_top2 else "東超（需前二）", GOLD, func(): try_enter_international("EASL"), Vector2(0, 50)))
		intl.add_child(action_button(bcl_caption if pro_top2 else "BCL（需前二）", RED, func(): try_enter_international("BCL"), Vector2(0, 50)))
	content.add_child(action_button("回大廳", Color("254e6b"), func(): show_dashboard(), Vector2(0, 48)))

func opponent_tactic(team_id: String) -> Dictionary:
	var adjustments: Dictionary = playoff_state.get("adaptations", {})
	if adjustments.get(team_id) is Dictionary:
		return adjustments[team_id].duplicate(true)
	var styles: Dictionary = tactic_rules.get("opponent_styles", {})
	var style = styles.get(team_id, {"offense":"半場傳導", "defense":"人盯人"})
	return style if style is Dictionary else {"offense":"半場傳導", "defense":"人盯人"}

func matchup_word(bonus: float) -> String:
	if bonus >= 1.2:
		return "克制"
	if bonus >= 0.4:
		return "略剋"
	if bonus <= -1.2:
		return "被剋"
	if bonus <= -0.4:
		return "略虧"
	return "互不吃虧"

func matchup_signed(bonus: float) -> String:
	return "%s%.1f" % ["+" if bonus >= 0.0 else "", bonus]

func tonight_vs_note(play: String, is_offense: bool, opponent: Dictionary) -> String:
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	if is_offense:
		var bonus := tactic_matchup_bonus(play, str(style.get("defense", "人盯人")))
		return "對今晚%s：%s %s" % [str(style.get("defense", "人盯人")), matchup_word(bonus), matchup_signed(bonus)]
	var bonus_d := defense_matchup_bonus(play, str(style.get("offense", "半場傳導")))
	return "對今晚%s：%s %s" % [str(style.get("offense", "半場傳導")), matchup_word(bonus_d), matchup_signed(bonus_d)]

func best_unlocked_vs(is_offense: bool, against: String) -> Dictionary:
	var best_id := ""
	var best := -99.0
	var pool: Array = unlocked_offense if is_offense else unlocked_defense
	for play in pool:
		var name := str(play)
		var bonus := tactic_matchup_bonus(name, against) if is_offense else defense_matchup_bonus(name, against)
		if bonus > best:
			best = bonus
			best_id = name
	return {"id": best_id, "bonus": best}

func tonight_counter_line(opponent: Dictionary) -> String:
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	var opp_off := str(style.get("offense", "半場傳導"))
	var opp_def := str(style.get("defense", "人盯人"))
	var atk := best_unlocked_vs(true, opp_def)
	var dfn := best_unlocked_vs(false, opp_off)
	var atk_id := str(atk.get("id", selected_tactic))
	var dfn_id := str(dfn.get("id", selected_defense))
	return "對方守%s → 用%s打。對方攻%s → 用%s守。" % [opp_def, atk_id, opp_off, dfn_id]

func tonight_matchup_panel(opponent: Dictionary) -> Control:
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	var opp_off := str(style.get("offense", "半場傳導"))
	var opp_def := str(style.get("defense", "人盯人"))
	var atk_bonus := tactic_matchup_bonus(selected_tactic, opp_def)
	var def_bonus := defense_matchup_bonus(selected_defense, opp_off)
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", panel_style(Color("1a0c08ee"), ORANGE, 10, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	shell.add_child(padded(box, 6))
	box.add_child(plain_label("對方戰術 · 相剋", 12, ORANGE, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(plain_label("攻 %s　守 %s" % [opp_off, opp_def], 13, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(wrap_label("你的%s＝%s %s　你的%s＝%s %s" % [
		selected_tactic, matchup_word(atk_bonus), matchup_signed(atk_bonus),
		selected_defense, matchup_word(def_bonus), matchup_signed(def_bonus),
	], 11, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(wrap_label(tonight_counter_line(opponent), 11, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	return shell

func tactic_matchup_bonus(attack_tactic: String, opponent_defense: String) -> float:
	var matrix: Dictionary = tactic_rules.get("offense", {})
	var row = matrix.get(attack_tactic, {})
	return float(row.get(opponent_defense, 0.0)) if row is Dictionary else 0.0

func defense_matchup_bonus(defense_tactic: String, opponent_offense: String) -> float:
	var matrix: Dictionary = tactic_rules.get("defense", {})
	var row = matrix.get(defense_tactic, {})
	return float(row.get(opponent_offense, 0.0)) if row is Dictionary else 0.0

func tactic_matchup_summary(opponent: Dictionary) -> String:
	return tactic_player_line(opponent)

func tactic_player_line(opponent: Dictionary) -> String:
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	var opp_def := str(style.get("defense", "人盯人"))
	var opp_off := str(style.get("offense", "半場傳導"))
	var blurb: Dictionary = tactic_blurb(selected_tactic)
	var vs := str(blurb.get("vs", ""))
	if vs.is_empty():
		vs = tactic_description(selected_tactic)
	return "對手%s（攻 %s）→ %s" % [opp_def, opp_off, vs]

func team_star(team: Dictionary) -> Dictionary:
	var players: Array = team.get("players", [])
	if players.is_empty() or not (players[0] is Dictionary):
		return {}
	return to_game_player(players[0])

func card_strip() -> HBoxContainer:
	var cards := HBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cards.add_theme_constant_override("separation", 8)
	return cards

func normalized_catalog_team(raw_team: Dictionary) -> Dictionary:
	# Limit newly issued base cards only. Never apply this to a player's save or
	# inventory: trained cards and grandfathered scout offers retain their OVR.
	var team: Dictionary = raw_team.duplicate(true)
	var catalog_team_id := str(team.get("id", ""))
	var catalog_team_name := str(FICTIONAL_TEAM_NAMES.get(catalog_team_id, team.get("name", "")))
	# Every catalog card must carry its printed club identity. Older roster rows
	# omitted these fields and consequently rendered without a crest/name.
	for raw in team.get("players", []):
		if not (raw is Dictionary):
			continue
		if str(raw.get("origin_team_id", "")).is_empty():
			raw["origin_team_id"] = catalog_team_id
		if str(raw.get("team", "")).is_empty():
			raw["team"] = catalog_team_name
	var purple: Array[Dictionary] = []
	for raw in team.get("players", []):
		if raw is Dictionary and int(raw.get("ovr", 0)) >= 86 and not is_locked_prize(raw) and golden_generation_profile(raw).is_empty():
			purple.append(raw)
	purple.sort_custom(func(a, b):
		if int(a.get("ovr", 0)) != int(b.get("ovr", 0)):
			return int(a.get("ovr", 0)) > int(b.get("ovr", 0))
		return str(a.get("id", a.get("name", ""))) < str(b.get("id", b.get("name", "")))
	)
	for i in range(5, purple.size()):
		purple[i]["ovr"] = 85
		purple[i]["color"] = "red"
	return team

func load_league_teams() -> void:
	league_teams.clear()
	if not FileAccess.file_exists(LEAGUE_TEAMS_PATH):
		return
	var file := FileAccess.open(LEAGUE_TEAMS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				league_teams.append(normalized_catalog_team(item))
		if team_players.size() < 5:
			team_players = default_starting_team()

func load_national_teams() -> void:
	national_teams.clear()
	world_cup_meta = {}
	if not FileAccess.file_exists(NATIONAL_TEAMS_PATH):
		return
	var file := FileAccess.open(NATIONAL_TEAMS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	world_cup_meta = parsed
	for item in parsed.get("teams", []):
		if not (item is Dictionary):
			continue
		var team: Dictionary = item.duplicate(true)
		var hydrated: Array = []
		for raw in team.get("players", []):
			if raw is Dictionary:
				hydrated.append(hydrate_national_player(raw, str(team.get("id", ""))))
		team["players"] = hydrated
		national_teams.append(team)

func load_jones_cup() -> void:
	jones_cup_meta = {}
	if not FileAccess.file_exists(JONES_CUP_PATH):
		return
	var file := FileAccess.open(JONES_CUP_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		jones_cup_meta = parsed

func named_club_player(player_name: String) -> Dictionary:
	for team in league_teams:
		for raw in team.get("players", []):
			if raw is Dictionary and str(raw.get("name", "")) == player_name:
				return raw
	return {}

func hydrate_national_player(raw: Dictionary, team_id: String) -> Dictionary:
	var player: Dictionary = raw.duplicate(true)
	var club := named_club_player(str(player.get("name", "")))
	if not club.is_empty():
		if str(player.get("origin_team_id", "")).is_empty():
			player["origin_team_id"] = str(club.get("origin_team_id", club.get("id", "")))
		if str(player.get("photo", "")).is_empty():
			player["photo"] = str(club.get("photo", ""))
			player["image"] = str(club.get("photo", club.get("image", "")))
		if int(player.get("ovr", 0)) <= 0:
			player["ovr"] = int(club.get("ovr", 75))
		if str(player.get("skill_id", "")).is_empty():
			player["skill_id"] = str(club.get("skill_id", ""))
	if str(player.get("origin_team_id", "")).is_empty():
		player["origin_team_id"] = team_id
	player["pos"] = str(player.get("position", player.get("pos", "SG")))
	player["position"] = player["pos"]
	return player

func national_team_by_id(team_id: String) -> Dictionary:
	for team in national_teams:
		if str(team.get("id", "")) == team_id:
			return team
	return {}

func team_rating(team: Dictionary) -> int:
	var players: Array = team.get("players", [])
	var values: Array[int] = []
	for item in players:
		if item is Dictionary:
			values.append(int(item.get("ovr", 70)))
	values.sort()
	values.reverse()
	var top := values.slice(0, mini(values.size(), 5))
	if top.is_empty():
		return 70
	var total := 0
	for value in top:
		total += value
	return int(round(float(total) / top.size()))

func official_rival(team: Dictionary) -> Dictionary:
	var team_id := str(team.get("id", ""))
	return {
		"name": fictional_team_name(team_id, str(team.get("name", "對手"))),
		"rating": team_rating(team) + mini(2 * difficulty_level, 12),
		"city": str(team.get("city", "")),
		"team_id": str(team.get("id", "")),
		"league": str(team.get("league", "")),
		"players": team.get("players", []).duplicate(true),
	}

func fictional_team_name(team_id: String, fallback: String = "對手") -> String:
	return str(FICTIONAL_TEAM_NAMES.get(team_id, fallback))

func fictional_rival(team: Dictionary) -> Dictionary:
	return official_rival(team)

func raw_team_player(team_id: String, index: int) -> Dictionary:
	for team in league_teams:
		if str(team.get("id", "")) == team_id:
			var players: Array = team.get("players", [])
			if index >= 0 and index < players.size() and players[index] is Dictionary:
				return players[index].duplicate(true)
	return {}

func player_skill_id_for(raw: Dictionary) -> String:
	var player: Dictionary = merge_public_stats(raw.duplicate(true))
	if str(player.get("name", "")) == "盧峻翔":
		return "lu_69_demon"
	var listed := listed_position_from_data(player)
	var pos := listed if not listed.is_empty() else normalize_pos_code(str(player.get("position", player.get("pos", "SG"))))
	var apg := float(player.get("apg", 0.0))
	var ppg := float(player.get("ppg", 0.0))
	var rpg := float(player.get("rpg", 0.0))
	var fg3 := float(player.get("fg3_pct", 0.0))
	var ovr := int(player.get("ovr", public_player_ovr(player)))
	if str(raw.get("skill_id", "")) == "team_ovr_aura" or bool(raw.get("combo_wild", false)):
		return "team_ovr_aura"
	if bool(raw.get("locked_prize", false)) and not str(raw.get("skill_id", "")).is_empty():
		return str(raw.get("skill_id", ""))
	if is_veteran_player(player):
		return "veteran_leadership"
	if apg >= 5.5 or (pos == "PG" and apg >= 4.0):
		return "floor_general"
	if apg >= 3.5 and ppg >= 8.0:
		return "playmaker"
	if ppg >= 16.5:
		return "volume_scorer"
	if fg3 >= 38.0 or (pos in ["SG", "SF"] and fg3 >= 35.0 and ppg >= 8.0):
		return "three_and_d"
	if fg3 >= 33.0 and ppg < 8.0:
		return "corner_three"
	if rpg >= 7.5 or (pos in ["PF", "C"] and rpg >= 5.5):
		return "glass_cleaner"
	if pos == "C" and apg >= 2.0:
		return "screen_hub"
	if str(player.get("skill_id", "")) in ["clutch", "lockdown", "hustle", "transition", "bench_spark"]:
		return str(player.get("skill_id", ""))
	var salt := absi(str(player.get("name", "")).hash()) % 3
	if pos == "PG":
		return ["floor_general", "playmaker", "hustle"][salt]
	if pos == "SG":
		return ["three_and_d", "volume_scorer", "lockdown"][salt]
	if pos == "SF":
		return ["two_way_wing", "transition", "corner_three"][salt]
	if pos == "PF":
		return ["glass_cleaner", "screen_hub", "hustle"][salt]
	return ["screen_hub", "glass_cleaner", "bench_spark"][salt]

func to_game_player(raw: Dictionary, image_override := "") -> Dictionary:
	var player := merge_public_stats(raw.duplicate(true))
	var moved_team := str(PLAYER_TEAM_OVERRIDES.get(str(player.get("name", "")), ""))
	if not moved_team.is_empty():
		player["origin_team_id"] = moved_team
		player["team"] = str(FICTIONAL_TEAM_NAMES.get(moved_team, player.get("team", "")))
	player = apply_veteran_card(player)
	var skill_id := player_skill_id_for(player)
	var ovr := clampi(int(player.get("ovr", public_player_ovr(player))), 65, 90)
	var photo := str(image_override) if not image_override.is_empty() else official_photo_path(player)
	player["pos"] = str(player.get("position", player.get("pos", "SG")))
	var listed := listed_position_from_data(player)
	if not listed.is_empty():
		player["pos"] = listed
		player["position"] = listed
	else:
		player["pos"] = normalize_pos_code(player["pos"])
		player["position"] = player["pos"]
	player["ovr"] = ovr
	player["image"] = photo
	player["photo"] = photo
	player.erase("energy") # Migrate legacy saves; stamina is no longer a game mechanic.
	player["skill_id"] = skill_id
	var profile: Dictionary = skill_profile(skill_id)
	player["skill_name"] = str(profile.get("name", "即戰力"))
	player["skill_description"] = str(profile.get("description", ""))
	# Fan-facing names are a presentation layer; the existing balanced skill
	# effect remains unchanged until a dedicated skill design is approved.
	if FAN_SKILL_NAMES.has(str(player.get("name", ""))):
		player["skill_name"] = str(FAN_SKILL_NAMES.get(str(player.get("name", ""))))
	player["salary_million"] = published_salary(player)
	player["color"] = player_tier_key(player)
	player["tier"] = str(player.get("tier", "RARE"))
	if str(player.get("origin_team_id", "")).is_empty():
		player["origin_team_id"] = origin_id(player)
	return player

func salary_after_card_cap(player: Dictionary, salary: int) -> int:
	var tier := ovr_tier_key(int(player.get("ovr", public_player_ovr(player))))
	if tier in ["cyan", "green", "blue"]:
		return mini(salary, 300)
	return salary

func published_salary(player: Dictionary) -> int:
	if bool(player.get("draft_2026", false)):
		return salary_after_card_cap(player, clampi(100 + maxi(0, int(player.get("ovr", 68)) - 68) * 25, PLAYER_SALARY_MIN, PLAYER_SALARY_MAX))
	var player_name := str(player.get("name", ""))
	var ovr := clampi(int(player.get("ovr", public_player_ovr(player))), 65, 90)
	var trained := int(player.get("training_sessions", 0))
	var vet := golden_generation_profile(player)
	if not vet.is_empty():
		var base := maxi(PLAYER_SALARY_MIN, int(vet.get("salary_million", 300)))
		var base_ovr := int(vet.get("ovr", ovr))
		return salary_after_card_cap(player, clampi(maxi(PLAYER_SALARY_MIN, base + maxi(0, ovr - base_ovr) * 25), PLAYER_SALARY_MIN, PLAYER_SALARY_MAX))
	# Current SBL cards use a lower league scale, including imports/students.
	# Veteran and diamond prize contracts keep their special-card rules.
	if origin_id(player).begins_with("sbl_") and not is_locked_prize(player):
		return clampi(50 + (ovr - 65) * 10, 50, 300)
	# 單位萬元。對齊 2025-26 公開／流出行情：林庭謙傳聞 4000–6000、阿巴西 2500、林書豪 3000、蔣淯安／曾祥鈞 1500、胡瓏貿 1300、林志傑／盧峻翔 1000。
	var named := 0
	match player_name:
		"林庭謙":
			named = 5000
		"林書豪":
			named = 3000
		"陳盈駿":
			named = 2800
		"阿巴西":
			named = 2500
		"劉錚":
			named = 1800
		"蔣淯安", "曾祥鈞":
			named = 1500
		"高錦瑋":
			named = 1430
		"胡瓏貿":
			named = 1300
		"盧峻翔":
			named = 1000
		"高國豪":
			named = 700
		"林秉聖":
			named = 680
		"李啟瑋", "林韋翰":
			named = 666
		"周桂羽":
			named = 600
		"陳又瑋":
			named = 583
		"張鎮衙", "雷蒙恩":
			named = 500
	if named > 0:
		return salary_after_card_cap(player, clampi(named + trained * 25, PLAYER_SALARY_MIN, PLAYER_SALARY_MAX))
	var foreign := str(player.get("identity", "local")) == "foreign"
	var student := str(player.get("identity", "local")) == "foreign_student"
	var sbl := origin_id(player).begins_with("sbl_")
	var pay := 100
	if foreign:
		pay = clampi(420 + (ovr - 72) * 38, 420, 1600)
	elif student:
		pay = clampi(180 + (ovr - 68) * 18, 180, 520)
	elif sbl:
		pay = clampi(100 + (ovr - 65) * 14, PLAYER_SALARY_MIN, 360)
	elif ovr >= 86:
		pay = 980 + (ovr - 86) * 160
	elif ovr >= 81:
		pay = 680 + (ovr - 81) * 55
	elif ovr >= 76:
		pay = 430 + (ovr - 76) * 48
	elif ovr >= 71:
		pay = 280 + (ovr - 71) * 28
	else:
		pay = clampi(100 + (ovr - 65) * 32, PLAYER_SALARY_MIN, 250)
	return salary_after_card_cap(player, clampi(pay, PLAYER_SALARY_MIN, PLAYER_SALARY_MAX))

func refresh_stored_player(player: Dictionary) -> Dictionary:
	player.erase("energy")
	if str(player.get("origin_team_id", "")).is_empty():
		player["origin_team_id"] = catalog_origin_id_for_player(player)
	if str(player.get("team", "")).is_empty() and not str(player.get("origin_team_id", "")).is_empty():
		player["team"] = team_display_name(str(player.get("origin_team_id", "")))
	var mapped_photo := official_photo_path(player)
	player["image"] = mapped_photo
	player["photo"] = mapped_photo
	player = apply_veteran_card(player)
	var listed := listed_position_from_data(player)
	if not listed.is_empty():
		player["pos"] = listed
		player["position"] = listed
	else:
		var normalized := normalize_pos_code(str(player.get("pos", player.get("position", ""))))
		if not normalized.is_empty():
			player["pos"] = normalized
			player["position"] = normalized
	if int(player.get("ovr", 65)) < 65:
		player["ovr"] = 65
	if not is_locked_prize(player):
		player["salary_million"] = published_salary(player)
	player["color"] = player_tier_key(player)
	return player

func catalog_origin_id_for_player(player: Dictionary) -> String:
	var direct := origin_id(player)
	if not direct.is_empty():
		return direct
	var wanted_id := str(player.get("id", ""))
	var wanted_names := player_name_keys(str(player.get("name", "")))
	for team in league_teams:
		for raw in team.get("players", []):
			if not (raw is Dictionary):
				continue
			if (not wanted_id.is_empty() and str(raw.get("id", "")) == wanted_id) or str(raw.get("name", "")) in wanted_names:
				return str(team.get("id", ""))
	return ""

func default_starting_team() -> Array[Dictionary]:
	return balanced_lineup([])

func balanced_lineup(prefer: Array) -> Array[Dictionary]:
	var slots := ["PG", "SG", "SF", "PF", "C"]
	var pool: Array[Dictionary] = []
	for item in prefer:
		if item is Dictionary:
			pool.append(item)
	for team in league_teams:
		if current_league == "SBL" and str(team.get("league", "")) != "SBL":
			continue
		for raw in team.get("players", []):
			if raw is Dictionary:
				pool.append(raw)
	var used: Dictionary = {}
	var result: Array[Dictionary] = []
	var prefer_count := 0
	for item in prefer:
		if item is Dictionary:
			prefer_count += 1
	for pos in slots:
		var pick: Dictionary = pick_lineup_player(pool, used, pos, prefer_count, result)
		if pick.is_empty():
			var side := "BACK" if pos in ["PG", "SG", "SF"] else "FRONT"
			pick = pick_lineup_player(pool, used, side, prefer_count, result)
		if pick.is_empty():
			pick = pick_lineup_player(pool, used, "", prefer_count, result)
		if pick.is_empty():
			continue
		used[player_identity_key(pick)] = true
		var card := to_game_player(pick)
		var listed := listed_position_from_data(card)
		if listed.is_empty():
			listed = normalize_pos_code(str(card.get("position", card.get("pos", "SG"))))
		if listed.is_empty():
			listed = "SG"
		card["pos"] = listed
		card["position"] = listed
		result.append(card)
	return result

func pick_lineup_player(pool: Array, used: Dictionary, pos: String, prefer_count: int, assembling: Array = []) -> Dictionary:
	for i in mini(prefer_count, pool.size()):
		var preferred = pool[i]
		if not (preferred is Dictionary):
			continue
		var pid := player_identity_key(preferred)
		if pid.is_empty() or used.has(pid):
			continue
		if not pos.is_empty() and not player_fits_slot(preferred, pos):
			continue
		if identity_blocked_among(preferred, assembling):
			continue
		return preferred
	for want_photo in [true, false]:
		for raw in pool:
			if not (raw is Dictionary):
				continue
			var pid := player_identity_key(raw)
			if pid.is_empty() or used.has(pid):
				continue
			if not pos.is_empty() and not player_fits_slot(raw, pos):
				continue
			if SHOW_OFFICIAL_PHOTOS and want_photo and official_photo_path(raw).is_empty():
				continue
			if identity_blocked_among(raw, assembling):
				continue
			return raw
	return {}

func identity_blocked_among(candidate: Dictionary, assembling: Array) -> bool:
	var foreigners := 0
	var students := 0
	for item in assembling:
		if not (item is Dictionary):
			continue
		if is_foreigner(item):
			foreigners += 1
		if is_foreign_student(item):
			students += 1
	if is_foreigner(candidate) and foreigners >= foreigner_limit():
		return true
	if is_foreign_student(candidate) and students >= foreign_student_limit():
		return true
	return false

func lineup_photo_hits(players: Array) -> int:
	var hits := 0
	for i in mini(5, players.size()):
		if players[i] is Dictionary and not official_photo_path(players[i]).is_empty():
			hits += 1
	return hits

func franchise_starter() -> Dictionary:
	if team_players.is_empty():
		return {}
	var star: Dictionary = team_players[0]
	for player in team_players:
		if not (player is Dictionary):
			continue
		if int(player.get("ovr", 0)) > int(star.get("ovr", 0)):
			star = player
	return star

func find_photographed_fill(pos: String, used: Dictionary, assembling: Array) -> Dictionary:
	for team in league_teams:
		if current_league == "SBL" and str(team.get("league", "")) != "SBL":
			continue
		for raw in team.get("players", []):
			if not (raw is Dictionary):
				continue
			var pid := str(raw.get("id", raw.get("name", "")))
			if used.has(pid):
				continue
			if not pos.is_empty() and not player_fits_slot(raw, pos):
				continue
			if official_photo_path(raw).is_empty():
				continue
			if identity_blocked_among(raw, assembling):
				continue
			return raw
	return {}

func ensure_photographed_starters() -> void:
	# 沒官方照就用名牌／插畫。不要為了湊照片把先發換成別人。
	return

func most_expensive_bench_index() -> int:
	var best := -1
	var best_sal := -1
	for i in range(5, team_players.size()):
		var sal := int(float(team_players[i].get("salary_million", 0)))
		if sal >= best_sal:
			best_sal = sal
			best = i
	return best

func stash_overflow_to_vault() -> bool:
	var dirty := false
	while team_players.size() > roster_limit():
		var idx := most_expensive_bench_index()
		if idx < 0:
			break
		if not stash_to_vault(team_players[idx]):
			break
		team_players.remove_at(idx)
		dirty = true
	while over_salary_cap() and team_players.size() > minimum_roster_to_play():
		var idx := most_expensive_bench_index()
		if idx < 0:
			break
		if not stash_to_vault(team_players[idx]):
			break
		team_players.remove_at(idx)
		dirty = true
	if dirty:
		apply_combo_label()
		flash_notice("超額／超帽球員已放入保管箱")
	return dirty

func ensure_bench() -> void:
	var dirty := stash_overflow_to_vault()
	if dirty:
		save_game()

func ensure_initial_roster() -> void:
	# Switching clubs must not mint a second copy of the starter players.
	if active_team_index != 0:
		return
	# Selection is optional. If a new club leaves the headline-player screen
	# without tapping a card, seed it with a visible recommendation instead of
	# leaving an unusable zero-player roster.
	if team_players.is_empty():
		var recommendations := sbl_star_pool()
		if not recommendations.is_empty():
			var recommendation: Dictionary = recommendations[0].duplicate(true)
			team_players = balanced_lineup([recommendation])
			selected_live_player = str(recommendation.get("name", ""))
			chemistry = maxi(chemistry, 52)
			last_event = "%s 自動加入為開季頭號球星；之後可在編隊調整。" % selected_live_player
		else:
			team_players = default_starting_team()
	while team_players.size() < minimum_roster_to_play():
		var fill := cheap_bench_player()
		if fill.is_empty():
			break
		team_players.append(fill)

func cheap_bench_player() -> Dictionary:
	var pool: Array[Dictionary] = []
	for team in league_teams:
		if current_league == "SBL" and str(team.get("league", "")) != "SBL":
			continue
		for raw in team.get("players", []):
			if not (raw is Dictionary):
				continue
			var card := to_game_player(raw)
			if team_has_player(card):
				continue
			if str(card.get("identity", "local")) == "foreign":
				continue
			pool.append(card)
	pool.sort_custom(func(a: Dictionary, b: Dictionary): return int(float(a.get("salary_million", 80))) < int(float(b.get("salary_million", 80))))
	if pool.is_empty():
		return {}
	var pick: Dictionary = {}
	if SHOW_OFFICIAL_PHOTOS:
		for card in pool:
			if not official_photo_path(card).is_empty():
				pick = card
				break
	if pick.is_empty():
		var want_origin := str(combo_state().get("origin", ""))
		if not want_origin.is_empty():
			for card in pool:
				if origin_id(card) == want_origin:
					pick = card
					break
		if pick.is_empty():
			pick = pool[0]
	pick["auto_bench"] = true
	pick["tier"] = "BENCH"
	pick["salary_million"] = published_salary(pick)
	pick.erase("energy")
	return pick

func player_name_keys(player_name: String) -> PackedStringArray:
	match player_name:
		"林洺威", "林銘威", "林子洧", "林子偉":
			return PackedStringArray(["林洺威", "林銘威", "林子洧", "林子偉"])
		"布蘭登", "莫斯":
			return PackedStringArray(["布蘭登", "莫斯"])
		_:
			return PackedStringArray([player_name])

func player_aka_line(player_name: String) -> String:
	match player_name:
		"林洺威", "林銘威", "林子洧", "林子偉":
			return "曾用名林子洧 · 高雄師大"
		"布蘭登", "莫斯":
			return "Brandon Moss · 舊登錄名莫斯"
		_:
			return ""

func photo_for_player_name(player_name: String) -> String:
	var keys := player_name_keys(player_name)
	for team in league_teams:
		for raw in team.get("players", []):
			if raw is Dictionary and str(raw.get("name", "")) in keys:
				var photo := str(raw.get("photo", ""))
				if not is_placeholder_photo(photo) and resource_exists(photo):
					return photo
	return ""

func is_placeholder_photo(path: String) -> bool:
	if path.is_empty():
		return true
	return path.contains("/assets/players/") or path.contains("/art/hero_") or path.contains("/portraits/heads/") or path.contains("/portraits/fallback/") or path.contains("/portraits/sbl_pure/")

func photo_path_variants(path: String) -> Array[String]:
	var out: Array[String] = []
	if path.is_empty():
		return out
	var seen: Dictionary = {}
	var stem := path.get_basename()
	for candidate in [path, stem + ".jpg", stem + ".jpeg", stem + ".png", stem + ".webp"]:
		if seen.has(candidate):
			continue
		seen[candidate] = true
		out.append(candidate)
	return out

func official_photo_path(player: Dictionary) -> String:
	if bool(player.get("draft_2026", false)):
		return ""
	var tried: Dictionary = {}
	var paths: Array[String] = []
	for key in ["photo", "image"]:
		var p := str(player.get(key, "")).strip_edges()
		if is_placeholder_photo(p):
			continue
		for variant in photo_path_variants(p):
			if not tried.has(variant):
				tried[variant] = true
				paths.append(variant)
	var pid := str(player.get("id", ""))
	var tid := str(player.get("origin_team_id", ""))
	if tid.is_empty():
		tid = team_id_from_display_name(str(player.get("team", "")))
	if not pid.is_empty() and not tid.is_empty():
		for folder in ["images", "portraits"]:
			for ext in ["png", "jpg", "webp"]:
				var constructed := "res://assets/%s/teams/%s/players/%s.%s" % [folder, tid, pid, ext]
				if not tried.has(constructed):
					tried[constructed] = true
					paths.append(constructed)
	var named := str(player.get("photo", ""))
	if named.is_empty():
		named = photo_for_public_player(player)
	if not is_placeholder_photo(named):
		for variant in photo_path_variants(named):
			if not tried.has(variant):
				tried[variant] = true
				paths.append(variant)
	for path in paths:
		if is_placeholder_photo(path):
			continue
		if photo_path_ok(player, path) and resource_exists(path):
			return path
	return ""

func photo_path_ok(player: Dictionary, path: String) -> bool:
	if path.is_empty() or is_placeholder_photo(path):
		return false
	# 這批 SBL 柏力力肖像對錯隊（伊波卡是特攻黃衫、其他人是攻城獅等）。
	if path.contains("/portraits/sbl_pure/"):
		return false
	var tid := str(player.get("origin_team_id", ""))
	if tid.is_empty():
		tid = team_id_from_display_name(str(player.get("team", "")))
	if not tid.is_empty() and path.contains("/teams/") and not path.contains("/teams/%s/" % tid):
		return false
	return true

func team_id_from_display_name(display_name: String) -> String:
	var aliases := {
		"台北悍將": "fubon",
		"台北先鋒": "fubon",
		"新北特工": "dea",
		"新北皇家": "kings",
		"桃園飛行員": "pilots",
		"新竹狂獅": "lioneers",
		"寶島追逐者": "dreamers",
		"寶島追夢者": "dreamers",
		"高雄波賽頓": "aquas",
		"台南飛鷹": "ghosthawks",
		"新竹洋基": "yankey",
		"台北戰士": "mars",
		"台灣烈酒": "sbl_beer",
		"台灣金控": "sbl_bank",
		"裕隆恐龍": "sbl_yulon",
		"彰化柏力力": "sbl_pure",
		"臺北富邦勇士": "fubon",
		"桃園璞園領航猿": "pilots",
		"台鋼獵鷹": "ghosthawks",
		"臺南台鋼獵鷹": "ghosthawks",
		"領航猿": "pilots",
		"桃園領航猿": "pilots",
		"新竹攻城獅": "lioneers",
		"洋基工程": "yankey",
		"新竹洋基工程": "yankey",
		"福爾摩沙夢想家": "dreamers",
		"新竹御嵿攻城獅": "lioneers",
		"高雄全家海神": "aquas",
		"新北中信特攻": "dea",
		"新北國王": "kings",
		"臺北台新戰神": "mars",
		"桃園台啤永豐雲豹": "leopards",
		"桃園雲豹": "leopards",
		"桃園黑豹": "leopards",
		"臺灣銀行": "sbl_bank",
		"台灣啤酒": "sbl_beer",
		"裕隆集團": "sbl_yulon",
		"裕隆納智捷恐龍": "sbl_yulon",
		"基隆黑鳶": "sbl_kites",
		"基隆黑鷲": "sbl_kites",
		"基隆雷鳥": "sbl_kites",
		"凱撒基隆黑鳶": "sbl_kites",
		"彰化璞園柏力力": "sbl_pure",
	}
	return str(aliases.get(display_name, ""))

func photo_for_public_player(player: Dictionary) -> String:
	var wanted_name := str(player.get("name", ""))
	var wanted_names := player_name_keys(wanted_name)
	var wanted_team := team_id_from_display_name(str(player.get("team", "")))
	for team in league_teams:
		if not wanted_team.is_empty() and str(team.get("id", "")) != wanted_team:
			continue
		for raw in team.get("players", []):
			if raw is Dictionary and str(raw.get("name", "")) in wanted_names:
				return str(raw.get("photo", ""))
	return photo_for_player_name(wanted_name)

func players_with_photos() -> Array[Dictionary]:
	var with_photo: Array[Dictionary] = []
	var without: Array[Dictionary] = []
	for raw in public_players:
		var card: Dictionary = raw.duplicate(true)
		var photo := str(card.get("photo", card.get("image", "")))
		if photo.is_empty():
			photo = photo_for_public_player(card)
		if resource_exists(photo) and photo_path_ok(card, photo):
			card["image"] = photo
			card["photo"] = photo
			with_photo.append(card)
		else:
			card["image"] = stylized_portrait_path(card)
			card["photo"] = card["image"]
			without.append(card)
	if not with_photo.is_empty():
		return with_photo
	return without

func load_public_players() -> void:
	public_players.clear()
	if not FileAccess.file_exists(PUBLIC_PLAYERS_PATH):
		return
	var file := FileAccess.open(PUBLIC_PLAYERS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				var player: Dictionary = item.duplicate(true)
				var photo := photo_for_public_player(player)
				if not photo.is_empty():
					player["photo"] = photo
					player["image"] = photo
				public_players.append(player)

func load_extra_team_rosters() -> void:
	extra_team_rosters.clear()
	if not FileAccess.file_exists(EXTRA_ROSTERS_PATH):
		return
	var file := FileAccess.open(EXTRA_ROSTERS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("teams") is Dictionary:
		extra_team_rosters = parsed.teams.duplicate(true)

func extra_team_players(team_id: String) -> Array:
	for team in league_teams:
		if str(team.get("id", "")) == team_id:
			return team.get("players", []).duplicate(true)
	for team in national_teams:
		if str(team.get("id", "")) == team_id:
			return team.get("players", []).duplicate(true)
	var pack = extra_team_rosters.get(team_id, {})
	if pack is Dictionary and pack.get("players") is Array:
		return pack.players.duplicate(true)
	return []

func public_player_ovr(player: Dictionary) -> int:
	var scoring := float(player.get("ppg", 0.0))
	var rebounding := float(player.get("rpg", 0.0))
	var passing := float(player.get("apg", 0.0))
	var efficiency := float(player.get("fg3_pct", 0.0)) * 0.025
	return clampi(int(round(65.0 + scoring * 1.05 + rebounding * 0.9 + passing * 0.75 + efficiency)), 65, 90)

func clear_screen() -> void:
	var old_bench := find_child("BenchScroll", true, false)
	if old_bench is ScrollContainer:
		phone_bench_scroll = old_bench.scroll_horizontal
	resource_hud_labels.clear()
	resource_hud_snapshot.clear()
	training_modal = null
	notice_node = null
	guide_modal = null
	card_reveal_modal = null
	share_modal = null
	trade_modal = null
	var keep: Array[Node] = []
	if is_instance_valid(sfx_player):
		keep.append(sfx_player)
	if is_instance_valid(bgm_player):
		keep.append(bgm_player)
	if is_instance_valid(cloud_http):
		keep.append(cloud_http)
	if is_instance_valid(news_http):
		keep.append(news_http)
	var doomed: Array[Node] = []
	for child in get_children():
		if child in keep:
			continue
		doomed.append(child)
	for child in doomed:
		# Leave the tree now so layout/draw stop, but queue_free so a
		# button that triggered this screen change is still valid this frame.
		remove_child(child)
		child.queue_free()
	modulate.a = 1.0

func _process(delta: float) -> void:
	if _app_suspended:
		return
	resource_hud_elapsed += delta
	if resource_hud_elapsed >= 0.2:
		resource_hud_elapsed = 0.0
		refresh_resource_hud()
	poll_auth_server()
	poll_web_auth_callback()
	_iap_poll_elapsed += delta
	if _iap_poll_elapsed >= 0.25:
		_iap_poll_elapsed = 0.0
		poll_native_iap()
	tick_cloud_autosave(delta)
	tick_cloud_status()
	if is_handheld():
		_safe_pad_elapsed += delta
		if _safe_pad_elapsed >= 0.5:
			_safe_pad_elapsed = 0.0
			refresh_safe_margins()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		handle_back_request()
		get_viewport().set_input_as_handled()
		return
	if current_stage == 6:
		return
	if not OS.has_feature("editor") and not OS.is_debug_build():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_0, KEY_H:
			show_dashboard()
		KEY_1:
			show_roster()
		KEY_2:
			show_market()
		KEY_3:
			show_gacha_market()
		KEY_4:
			show_more_hub()
		KEY_5, KEY_M:
			show_match_prep()
		KEY_6:
			show_game_guide()
		KEY_N:
			show_news_center()
		KEY_S:
			show_save_slots()

func compact_phone() -> bool:
	# Compact layout follows the logical canvas; touch targets use is_handheld().
	return get_viewport_rect().size.y < 560

func is_handheld() -> bool:
	return OS.has_feature("mobile") or (OS.has_feature("web") and DisplayServer.is_touchscreen_available()) or OS.get_environment("TB_FITSHOT") == "1" or OS.get_environment("TB_SCOUT") == "1"

func touch_minimum(minimum: Vector2) -> Vector2:
	if not is_handheld():
		return minimum
	return Vector2(maxf(minimum.x, MOBILE_TOUCH_SIZE) if minimum.x > 0 else 0, maxf(minimum.y, MOBILE_TOUCH_SIZE))

func usable_view() -> Vector2:
	var pad := screen_safe_pad()
	var view := get_viewport_rect().size
	return Vector2(maxf(200.0, view.x - float(pad.x + pad.z)), maxf(120.0, view.y - float(pad.y + pad.w)))

func fit_card_width(cols: int, row_budget_h: float) -> int:
	var n := maxi(cols, 1)
	var by_w := int(floor((usable_view().x - 8.0 * float(n - 1) - 12.0) / float(n)))
	var by_h := int(floor(maxf(row_budget_h - 18.0, 72.0) * 0.68))
	return clampi(mini(by_w, by_h), 64, 92)

func content_view_h() -> float:
	var pad := screen_safe_pad()
	var top := 48.0 if compact_phone() else 62.0
	var dock := 60.0 if compact_phone() else 76.0
	return maxf(140.0, get_viewport_rect().size.y - float(pad.y + pad.w) - top - dock)

func body_row_h() -> int:
	return clampi(int((content_view_h() - 52.0) / 6.0), 32, 48)

func screen_arena_tex() -> Texture2D:
	var themed_arenas := {
		"台北雨夜河濱": "res://assets/art/arenas/taiwan/taipei_riverside.png",
		"新北籃球聖殿": "res://assets/art/arenas/taiwan/new_taipei_xinzhuang.png",
		"台中弧光主場": "res://assets/art/arenas/taiwan/taichung_arc.png",
		"台南古都夜場": "res://assets/art/arenas/taiwan/tainan_oldtown.png",
		"高雄港灣夕照": "res://assets/art/arenas/taiwan/kaohsiung_harbor.png",
		"花蓮山海晨光": "res://assets/art/arenas/taiwan/hualien_coast.png",
		"月影雲海球場": "res://assets/art/arenas/monthly_moon.png",
	}
	if themed_arenas.has(supporter_theme):
		var themed := load_png_tex(str(themed_arenas[supporter_theme]))
		if themed != null:
			return themed
	if supporter_theme == "賽博龐克主場":
		var cyber := load_png_tex("res://assets/art/arenas/cyberpunk_arena_base.png")
		if cyber != null:
			return cyber
	if supporter_theme == "冠軍金色主場":
		var champion := load_png_tex("res://assets/art/arena_playoff.png")
		if champion != null:
			return champion
	if supporter_theme == "夜場靛藍":
		var indigo := load_png_tex("res://assets/art/arena_night.png")
		if indigo != null:
			return indigo
	if season_phase in ["semifinal", "final", "champion"]:
		var playoff := load_png_tex("res://assets/art/arena_playoff.png")
		if playoff != null:
			return playoff
	var night := load_png_tex("res://assets/art/arena_night.png")
	if night != null:
		return night
	return load_png_tex("res://assets/ui/arena_bg.png")

func locker_room_tex() -> Texture2D:
	var rooms := {
		"木質職業更衣室": "res://assets/art/locker_rooms/pro_wood.png",
		"黑金冠軍更衣室": "res://assets/art/locker_rooms/champion_black_gold.png",
		"霓虹科技更衣室": "res://assets/art/locker_rooms/neon_tech.png",
		"復古台籃更衣室": "res://assets/art/locker_rooms/retro_taiwan.png",
	}
	if rooms.has(locker_room_theme):
		return load_png_tex(str(rooms[locker_room_theme]))
	return load_png_tex("res://assets/art/locker_rooms/basic.png")

func hud_icon(path: String, box := 22) -> TextureRect:
	var glyph := TextureRect.new()
	glyph.texture = load_png_tex(path)
	glyph.custom_minimum_size = Vector2(box, box)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.clip_contents = false
	return glyph

func begin_screen(title: String, subtitle: String, stage: int, show_resources := true, show_dock := true) -> VBoxContainer:
	if stage != 6:
		match_play_id += 1
	clear_screen()
	current_stage = stage
	var skin_accent: Color = supporter_accent()
	var phone := compact_phone()

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The dashboard uses deliberately composed clubhouse key art. Keeping the
	# person and architecture in the backdrop avoids stretching a card portrait.
	if active_menu == "dashboard":
		bg.texture = locker_room_tex() if home_environment_mode == "locker" else load_png_tex("res://assets/art/lobby/home_clubhouse_v2.png")
	else:
		bg.texture = screen_arena_tex()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.18 if active_menu == "dashboard" else 0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := screen_safe_pad()
	margin.add_theme_constant_override("margin_left", pad.x)
	margin.add_to_group("screen_safe_margins")
	margin.add_theme_constant_override("margin_right", pad.z)
	margin.add_theme_constant_override("margin_top", pad.y)
	margin.add_theme_constant_override("margin_bottom", pad.w)
	add_child(margin)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 2 if is_handheld() else 10)
	margin.add_child(page)

	var top := PanelContainer.new()
	top.name = "TopBar"
	var dashboard_top := active_menu == "dashboard"
	top.custom_minimum_size = Vector2(0, UI_TOP_BAR_HEIGHT_PHONE if is_handheld() else (72 if dashboard_top else UI_TOP_BAR_HEIGHT_DESKTOP))
	top.add_theme_stylebox_override("panel", glass_style(14))
	page.add_child(top)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 8 if is_handheld() else 10)
	top_margin.add_theme_constant_override("margin_right", 6 if is_handheld() else 8)
	top_margin.add_theme_constant_override("margin_top", 3 if is_handheld() else 4)
	top_margin.add_theme_constant_override("margin_bottom", 3 if is_handheld() else 4)
	top.add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6 if is_handheld() else 8)
	top_margin.add_child(top_row)
	var brand := Button.new()
	brand.custom_minimum_size = touch_minimum(Vector2(44 if is_handheld() else 52, 44 if is_handheld() else 52))
	brand.flat = true
	brand.clip_contents = true
	brand.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	brand.add_theme_stylebox_override("normal", panel_style(Color("1a1408ee"), GOLD, 10, 1))
	brand.add_theme_stylebox_override("hover", panel_style(Color("1a1408ee"), ORANGE, 10, 1))
	brand.add_theme_stylebox_override("pressed", panel_style(Color("1a1408ee"), TEXT, 10, 1))
	var brand_art := team_logo_rect(ensure_club_logo_id(), 40 if is_handheld() else 48, club_name)
	brand_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brand_art.offset_left = 2
	brand_art.offset_top = 2
	brand_art.offset_right = -2
	brand_art.offset_bottom = -2
	brand_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(brand_art)
	if title == "商店" and stage == 4:
		brand_art.visible = false
		brand.text = "‹"
		brand.add_theme_font_override("font", FONT_BOLD)
		brand.add_theme_font_size_override("font_size", 30)
		brand.pressed.connect(func():
			play_sfx("tap")
			handle_back_request()
		)
	elif stage >= 3 and stage != 6:
		brand.pressed.connect(func():
			play_sfx("tap")
			jump_shortcut(show_club_logo_picker)
		)
	top_row.add_child(brand)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if is_handheld() else Control.SIZE_EXPAND_FILL
	if is_handheld():
		title_box.custom_minimum_size.x = 96
		# On very narrow landscape canvases the club button remains available and
		# the title yields its space to the three always-visible resource balances.
		title_box.visible = get_viewport_rect().size.x >= 700.0
	title_box.clip_contents = true
	top_row.add_child(title_box)
	if active_menu == "dashboard" and title == club_display_name():
		var rename_title := Button.new()
		rename_title.text = title
		rename_title.flat = true
		rename_title.alignment = HORIZONTAL_ALIGNMENT_LEFT
		rename_title.tooltip_text = "點一下修改俱樂部名稱"
		rename_title.add_theme_font_override("font", FONT_BOLD)
		rename_title.add_theme_font_size_override("font_size", 18 if phone else 22)
		rename_title.add_theme_color_override("font_color", GOLD)
		rename_title.add_theme_stylebox_override("normal", invisible_style())
		rename_title.add_theme_stylebox_override("hover", invisible_style())
		rename_title.add_theme_stylebox_override("pressed", invisible_style())
		rename_title.pressed.connect(func(): show_rename_club_modal())
		title_box.add_child(rename_title)
	else:
		var title_lab := polish_title(fit_label(title, 18 if phone else 22, GOLD, true))
		title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_box.add_child(title_lab)
	if not equipped_badges.is_empty():
		var badges_lab := fit_label(equipped_badge_text(), 10 if phone else 11, GOLD, true)
		badges_lab.tooltip_text = "已裝備徽章（最多兩枚）"
		title_box.add_child(badges_lab)
	var sub_lab := kicker_label(subtitle, 10, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	sub_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# On phones the subtitle was the last source of a 79px header at narrow widths.
	# The screen title remains; details already appear in the page body.
	sub_lab.visible = not is_handheld()
	title_box.add_child(sub_lab)
	if title == "編隊" and not is_handheld():
		top_row.add_child(compact_combo_chip())
	if stage >= 3 and stage != 6 and second_team_unlocked:
		top_row.add_child(team_switch_chip())

	if is_handheld() and (show_resources or stage >= 3 or not team_players.is_empty()):
		var resource_spacer := Control.new()
		resource_spacer.name = "ResourceRightSpacer"
		resource_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(resource_spacer)
		top_row.add_child(hud_economy_row())
	if show_resources and not is_handheld():
		top_row.add_child(hud_economy_row(true))
		if active_menu != "dashboard":
			top_row.add_child(hud_shortcut(mission_shortcut_title(), "match", ORANGE, func():
				jump_shortcut(show_challenge_hub)
			))
			top_row.add_child(hud_shortcut("商店", "save", GOLD, func():
				jump_shortcut(show_store_hub)
			))
		else:
			top_row.add_child(hud_shortcut("☰", "more", GOLD, func():
				jump_shortcut(show_more_hub)
			))
	if stage > 0 and stage != 3 and stage != 6 and title != "商店":
		top_row.add_child(page_back_chip(stage))

	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0 if is_handheld() else 11)
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 12 if is_handheld() else 0
	scroll.name = "ContentScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	page.add_child(scroll)
	scroll.add_child(content)
	bind_scroll_child_width(scroll, content)
	fill_scroll_body(content)
	if show_dock and stage >= 3 and stage < 6:
		page.add_child(bottom_navigation())
	modulate.a = 1.0
	return content

func bind_scroll_child_width(scroll: ScrollContainer, child: Control) -> void:
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Keep a gutter so the vertical bar never changes content width.
	# Writing custom_minimum_size from resized loops _update_minimum_size.
	var vbar := scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.custom_minimum_size.x = maxf(vbar.custom_minimum_size.x, 8.0)

func fit_label(text_value: String, font_px: int, color := TEXT, bold := false, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := plain_label(text_value, font_px, color, bold, alignment)
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func nav_icon_tex(icon_id: String) -> Texture2D:
	return load_png_tex(str(NAV_ICONS.get(icon_id, "")))

func hub_art_tex(icon_id: String) -> Texture2D:
	if icon_id.is_empty():
		return null
	return load_png_tex(str(HUB_ART.get(icon_id, "")))

func bottom_navigation() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	bar.name = "BottomNavigation"
	bar.custom_minimum_size = Vector2(0, UI_BOTTOM_BAR_HEIGHT_PHONE if is_handheld() else (44 if active_menu == "dashboard" else UI_BOTTOM_BAR_HEIGHT_DESKTOP))
	var dock_style := panel_style(Color(0.035, 0.05, 0.075, 0.78), Color(0.96, 0.78, 0.32, 0.22), 14, 1)
	if is_handheld():
		dock_style.content_margin_top = 0
		dock_style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("panel", invisible_style() if active_menu == "dashboard" else dock_style)
	if active_menu == "dashboard":
		bar.add_child(dashboard_skin("res://assets/ui/home/nav_dock_skin_trim_v1.png"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3 if active_menu == "dashboard" else (6 if is_handheld() else 8))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(padded(row, 1 if is_handheld() else 4))
	row.add_child(dock_tab("首頁", active_menu == "dashboard", func():
		clear_return_stack()
		show_dashboard()
	, "res://assets/ui/icons/nav_home.png"))
	row.add_child(dock_tab("球隊", active_menu in ["roster", "tactics", "vault"], func():
		clear_return_stack()
		show_roster(false)
	, "res://assets/ui/icons/nav_roster.png"))
	row.add_child(dock_tab("比賽", active_menu in ["match", "result"], func():
		clear_return_stack()
		show_match_prep()
	, "res://assets/art/lobby/match.png"))
	row.add_child(dock_tab("商店", active_menu == "store", func():
		clear_return_stack()
		show_store_hub()
	, NAV_ICONS.market))
	row.add_child(dock_tab("更多", active_menu in ["more", "market", "collection", "activity", "async", "tasks", "challenge", "guide", "news", "league"], func():
		clear_return_stack()
		show_more_hub()
	, "res://assets/ui/icons/nav_more.png"))
	return bar

func dock_tab(caption: String, selected: bool, action: Callable, icon_path := "") -> Button:
	var hit := Button.new()
	hit.set_meta("button_role", "primary" if selected else "navigation")
	hit.text = ""
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.custom_minimum_size = Vector2(0, 42 if active_menu == "dashboard" else 54) if is_handheld() else Vector2(0, 42 if active_menu == "dashboard" else 48)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0) if active_menu == "dashboard" else (Color(0.16, 0.12, 0.05, 0.44) if selected else Color(0.06, 0.08, 0.12, 0.10))
	style.border_color = GOLD
	style.border_width_bottom = 0 if active_menu == "dashboard" else (2 if selected else 0)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	var hover := style.duplicate()
	hover.bg_color = Color(0.16, 0.13, 0.06, 0.42)
	hover.border_width_bottom = 3
	hit.add_theme_stylebox_override("normal", style)
	hit.add_theme_stylebox_override("hover", hover)
	hit.add_theme_stylebox_override("pressed", style)
	var col: BoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0 if is_handheld() else 2)
	hit.add_child(col)
	var resolved_icon_path := icon_path
	if active_menu == "dashboard":
		resolved_icon_path = {
			"首頁": "res://assets/ui/icons/dashboard_home.svg",
			"球隊": "res://assets/ui/icons/dashboard_team.svg",
			"比賽": "res://assets/ui/icons/dashboard_match.svg",
			"商店": "res://assets/ui/icons/dashboard_store.svg",
			"更多": "res://assets/ui/icons/dashboard_more.svg",
		}.get(caption, icon_path)
	var icon_tex := load_svg_tex(resolved_icon_path, 96) if resolved_icon_path.ends_with(".svg") else load_png_tex(resolved_icon_path)
	if icon_tex != null:
		var glyph := TextureRect.new()
		glyph.texture = icon_tex
		glyph.custom_minimum_size = Vector2(23 if active_menu == "dashboard" else 32, 23 if active_menu == "dashboard" else 32) if is_handheld() else (Vector2(30, 30) if active_menu == "dashboard" else Vector2(24, 24))
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(glyph)
	var caption_label := plain_label(caption, 9 if active_menu == "dashboard" else 12, GOLD if selected else Color(0.82, 0.86, 0.91, 0.92), true, HORIZONTAL_ALIGNMENT_CENTER)
	caption_label.add_theme_color_override("font_shadow_color", Color("000000ee"))
	caption_label.add_theme_constant_override("shadow_offset_x", 1)
	caption_label.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(caption_label)
	hit.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	bind_press_juice(hit, hit)
	return hit

func team_switch_chip() -> Button:
	var button := Button.new()
	button.text = "主隊 %d/2" % (active_team_index + 1)
	button.tooltip_text = "切換第一／第二隊"
	button.custom_minimum_size = touch_minimum(Vector2(72 if is_handheld() else 82, 34))
	button.add_theme_font_override("font", FONT_BOLD)
	button.add_theme_font_size_override("font_size", 12 if is_handheld() else 13)
	button.add_theme_stylebox_override("normal", panel_style(Color("17283aee"), CYAN.darkened(0.35), 10, 1))
	button.add_theme_stylebox_override("hover", panel_style(Color("203b50ee"), CYAN, 10, 1))
	button.add_theme_stylebox_override("pressed", panel_style(Color("102231ee"), TEXT, 10, 1))
	button.pressed.connect(func(): cycle_team_profile())
	return button

func nav_icon(caption: String, icon_id: String, selected: bool, action: Callable, circle := 52) -> Control:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(72, 0)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 4)
	var face := art_thumb(icon_id, Vector2(circle, circle))
	var hit := Button.new()
	hit.text = ""
	hit.custom_minimum_size = Vector2(circle, circle)
	hit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hit.clip_contents = false
	var rim := GOLD if selected else Color(1, 1, 1, 0.22)
	hit.add_theme_stylebox_override("normal", panel_style(Color(0.06, 0.08, 0.12, 0.4), rim, 12, 1 if selected else 1))
	hit.add_theme_stylebox_override("hover", panel_style(Color(0.1, 0.12, 0.16, 0.2), GOLD, 12, 2))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(0.04, 0.05, 0.08, 0.5), TEXT, 12, 1))
	hit.add_child(face)
	hit.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	bind_press_juice(hit, hit)
	holder.add_child(hit)
	holder.add_child(plain_label(caption, 12, GOLD if selected else TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	return holder

func art_thumb(icon_id: String, box_size: Vector2) -> TextureRect:
	var glyph := TextureRect.new()
	glyph.texture = nav_icon_tex(icon_id)
	glyph.custom_minimum_size = box_size
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph

func hud_shortcut(title: String, _icon_id: String, accent: Color, action: Callable) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = touch_minimum(Vector2(48, 34))
	holder.add_theme_stylebox_override("panel", panel_style(Color(0.06, 0.08, 0.12, 0.82), accent.darkened(0.12), 10, 1))
	var lab := plain_label(title, 20 if is_handheld() else 12, accent, true, HORIZONTAL_ALIGNMENT_CENTER)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(padded(lab, 6))
	var hit := Button.new()
	hit.text = ""
	hit.tooltip_text = title
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.flat = true
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", panel_style(Color(1, 1, 1, 0.08), accent, 10, 0))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(1, 1, 1, 0.14), TEXT, 10, 0))
	hit.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	holder.add_child(hit)
	bind_press_juice(holder, hit)
	return holder

func command_icon_button(icon_id: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.clip_contents = true
	button.custom_minimum_size = Vector2(40, 40)
	button.tooltip_text = {"news": "新聞", "guide": "指南", "save": "存檔"}.get(icon_id, icon_id)
	button.add_theme_stylebox_override("normal", panel_style(Color(0.06, 0.08, 0.12, 0.35), Color(1, 1, 1, 0.2), 10, 1))
	button.add_theme_stylebox_override("hover", panel_style(Color(0.1, 0.12, 0.16, 0.2), GOLD, 10, 1))
	button.add_theme_stylebox_override("pressed", panel_style(Color(0.04, 0.05, 0.08, 0.5), TEXT, 10, 1))
	button.add_child(art_thumb(icon_id, Vector2(40, 40)))
	button.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	return button

func clear_return_stack() -> void:
	return_stack.clear()
	prep_extra_event = ""

func current_screen_callable() -> Callable:
	match active_menu:
		"activity":
			return show_activity_hub
		"async":
			return show_async_season
		"tasks":
			return show_daily_tasks
		"match":
			return show_extra_match_prep if not prep_extra_event.is_empty() else show_match_prep
		"roster":
			return show_roster
		"tactics":
			return show_tactics
		"league":
			return show_league_overview
		"news":
			return show_news_center
		"market":
			return show_market
		"collection":
			return show_gacha_market
		"guide":
			return show_game_guide
		"more":
			return show_more_hub
		"challenge":
			return show_challenge_hub
		"store":
			return show_store_hub
		"dashboard":
			return show_dashboard
		"vault":
			return show_card_vault
		_:
			return show_dashboard

func open_sub(back: Callable, dest: Callable) -> void:
	if back.is_valid():
		return_stack.append(back)
	dest.call()

func jump_shortcut(dest: Callable) -> void:
	var here := current_screen_callable()
	if here == dest:
		dest.call()
		return
	open_sub(here, dest)

func go_return_page() -> void:
	while not return_stack.is_empty():
		var fn: Variant = return_stack.pop_back()
		if fn is Callable and (fn as Callable).is_valid():
			(fn as Callable).call()
			return
	dismiss_current_view(current_stage)

func page_back_button() -> Button:
	return action_button("上一頁", Color("254e6b"), func(): go_return_page(), Vector2(0, 48))

func page_back_chip(_stage: int) -> Button:
	var close := action_button("返回", Color("27394a"), func(): go_return_page(), Vector2(72, 44))
	close.tooltip_text = "回到上一頁"
	close.add_theme_font_size_override("font_size", 22 if is_handheld() else 13)
	close.add_theme_color_override("font_color", TEXT)
	return close

func mobile_close_button(stage: int) -> Button:
	return page_back_chip(stage)

func dismiss_current_view(stage: int) -> void:
	clear_return_stack()
	if stage >= 3:
		show_dashboard()
	else:
		show_login()

func show_more_hub() -> void:
	active_menu = "more"
	apply_salary_cap()
	request_web_news(false)
	var content := begin_screen("更多", "依類別直向排列 · 找球員請到下方「市場」", 4)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	var groups := [
		["賽事", CYAN, [["活動", show_activity_hub], ["聯盟戰績", show_league_overview], ["額外比賽", show_extra_events], ["休賽季", show_offseason]]],
		["球隊", GREEN, [["市場", show_market], ["保管箱", show_card_vault], ["數據王", show_stat_kings], ["任務", show_challenge_hub]]],
		["資訊", GOLD, [["新聞", show_news_center], ["遊戲指南", show_game_guide], ["官方社群", show_line_community]]],
		["系統", MUTED, [["商店", show_store_hub], ["設定", show_settings_hub]]]
	]
	for group in groups:
		var col := VBoxContainer.new()
		col.name = "MoreCategory" + str(columns.get_child_count())
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 8)
		columns.add_child(col)
		col.add_child(label(str(group[0]), 16, group[1], true))
		for entry in group[2]:
			var destination: Callable = entry[1]
			var button := action_button(str(entry[0]), Color("254052"), func(): open_sub(show_more_hub, destination))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if str(entry[0]) == "休賽季":
				button.disabled = season_phase not in ["offseason", "champion"]
			col.add_child(button)

func show_stat_kings() -> void:
	active_menu = "more"
	var content := begin_screen("數據王", "入隊後場均，至少打過 1 場", 4)
	if team_stat_king("club_pts").is_empty():
		content.add_child(callout("還沒排行", "打完一場，先發與替補都會留下入隊數據。", MUTED))
	else:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		content.add_child(row)
		row.add_child(king_stat_card("得分王", "club_pts", "分", GOLD))
		row.add_child(king_stat_card("籃板王", "club_reb", "籃板", CYAN))
		row.add_child(king_stat_card("助攻王", "club_ast", "助攻", ORANGE))
		content.add_child(label("全隊場均", 16, GOLD, true))
		var ranked: Array = []
		for player in team_players:
			if player is Dictionary and club_gp(player) > 0:
				ranked.append(player)
		ranked.sort_custom(func(a, b): return club_avg(a, "club_pts") > club_avg(b, "club_pts"))
		for player in ranked:
			content.add_child(club_avg_row(player))

func king_stat_card(title: String, total_key: String, unit: String, accent: Color) -> Control:
	var king: Dictionary = team_stat_king(total_key)
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.custom_minimum_size = Vector2(0, 86 if compact_phone() else 104)
	shell.add_theme_stylebox_override("panel", panel_style(Color("0d1c2bed"), accent.darkened(0.22), 12, 1))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	shell.add_child(padded(box, 8))
	box.add_child(kicker_label(title, 11, accent, HORIZONTAL_ALIGNMENT_CENTER))
	if king.is_empty():
		box.add_child(plain_label("—", 16, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
		return shell
	box.add_child(plain_label(str(king.get("name", "球員")), 15, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(plain_label("%.1f %s" % [club_avg(king, total_key), unit], 18, accent, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(plain_label("%d 場" % club_gp(king), 11, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	var idx := roster_index_of(king)
	if idx >= 0:
		var hit := Button.new()
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.flat = true
		hit.add_theme_stylebox_override("normal", invisible_style())
		hit.add_theme_stylebox_override("hover", invisible_style())
		hit.add_theme_stylebox_override("pressed", invisible_style())
		hit.add_theme_stylebox_override("focus", invisible_style())
		hit.pressed.connect(func():
			play_sfx("tap")
			show_player_sheet(team_players[idx], func(): show_stat_kings(), Callable(), "", idx)
		)
		bind_press_juice(shell, hit)
		shell.add_child(hit)
	return shell

func club_avg_row(player: Dictionary) -> Control:
	var pack := club_stat_pack(player)
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	row.add_theme_stylebox_override("panel", panel_style(Color("0d1c2bed"), GOLD.darkened(0.45), 10, 1))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(padded(box, 7))
	var who := plain_label(str(player.get("name", "球員")), 13, TEXT, true)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(who)
	box.add_child(plain_label("%d場" % int(pack.get("gp", 0)), 12, MUTED, true))
	box.add_child(plain_label("%.1f分" % float(pack.get("ppg", 0.0)), 13, GOLD, true))
	box.add_child(plain_label("%.1f籃" % float(pack.get("rpg", 0.0)), 12, MUTED, true))
	box.add_child(plain_label("%.1f助" % float(pack.get("apg", 0.0)), 12, MUTED, true))
	var idx := roster_index_of(player)
	if idx >= 0:
		var hit := Button.new()
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.flat = true
		hit.add_theme_stylebox_override("normal", invisible_style())
		hit.add_theme_stylebox_override("hover", invisible_style())
		hit.add_theme_stylebox_override("pressed", invisible_style())
		hit.add_theme_stylebox_override("focus", invisible_style())
		hit.pressed.connect(func():
			play_sfx("tap")
			show_player_sheet(team_players[idx], func(): show_stat_kings(), Callable(), "", idx)
		)
		row.add_child(hit)
	return row

func show_settings_hub() -> void:
	active_menu = "more"
	var content := begin_screen("設定", "音樂與音效，關了就不再出聲。", 4)
	content.add_child(action_button("更換隊徽", GOLD, func(): open_sub(show_settings_hub, show_club_logo_picker), Vector2(0, 52)))
	content.add_child(settings_block())
	if not auth_access.is_empty():
		content.add_child(cloud_status_panel())
		var sync_actions := GridContainer.new()
		sync_actions.columns = 2
		sync_actions.add_theme_constant_override("h_separation",6)
		sync_actions.add_theme_constant_override("v_separation",6)
		content.add_child(sync_actions)
		sync_actions.add_child(action_button("重新同步雲端", CYAN, func(): CloudSync.resume(self)))
		sync_actions.add_child(action_button("檢查存檔／選擇進度", GOLD, func(): CloudSync.show_choices(self)))
		sync_actions.add_child(action_button("匯入舊版／離線存檔", CYAN, func(): LocalProfiles.show_import(self)))
		sync_actions.add_child(action_button("更換帳號／重新登入", MUTED, logout_account))
		if cloud_restore_incomplete:
			content.add_child(wrap_label("本機進度保留。同步尚未確認或兩台裝置有不同進度時，先暫停自動上傳；可在這裡重試或選擇存檔。", 13, GOLD))
	content.add_child(legal_notice_button())

func settings_block() -> Control:
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", glass_style(14))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	shell.add_child(padded(box, 10))
	box.add_child(kicker_label("聲音", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(audio_toggle("音樂", bgm_on, func():
		bgm_on = not bgm_on
		save_audio_settings()
		apply_audio_settings()
		show_settings_hub()
	))
	row.add_child(audio_toggle("音效", sfx_on, func():
		sfx_on = not sfx_on
		save_audio_settings()
		apply_audio_settings()
		show_settings_hub()
	))
	var volume_row := HBoxContainer.new()
	volume_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_row.add_theme_constant_override("separation", 8)
	box.add_child(volume_row)
	volume_row.add_child(kicker_label("音樂音量", 11, MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var volume := HSlider.new()
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.custom_minimum_size = Vector2(180, 30)
	volume.min_value = 0.0
	volume.max_value = 100.0
	volume.step = 1.0
	volume.value = bgm_volume * 100.0
	volume.tooltip_text = "調整背景音樂音量"
	volume_row.add_child(volume)
	var volume_value := plain_label("%d%%" % int(round(bgm_volume * 100.0)), 12, GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
	volume_value.custom_minimum_size = Vector2(42, 0)
	volume_row.add_child(volume_value)
	volume.value_changed.connect(func(value: float):
		bgm_volume = clampf(value / 100.0, 0.0, 1.0)
		volume_value.text = "%d%%" % int(round(bgm_volume * 100.0))
		save_audio_settings()
		apply_audio_settings()
	)
	box.add_child(wrap_label("音樂：Non-Stop Hip-Hop For Streamers（循環）", 11, MUTED))
	return shell

func audio_settings_bar() -> Control:
	return settings_block()

func audio_toggle(title: String, on: bool, action: Callable) -> Button:
	var hit := Button.new()
	hit.text = "%s　%s" % [title, "開" if on else "關"]
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.custom_minimum_size = Vector2(0, 40)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var accent := GOLD if on else MUTED
	var fill := Color(0.16, 0.12, 0.05, 0.92) if on else Color(0.06, 0.08, 0.11, 0.88)
	hit.add_theme_font_override("font", FONT_BOLD)
	hit.add_theme_font_size_override("font_size", 15)
	hit.add_theme_color_override("font_color", Color("fff6d8") if on else TEXT)
	punch_text(hit, 15)
	hit.add_theme_stylebox_override("normal", panel_style(fill, accent, 10, 1))
	hit.add_theme_stylebox_override("hover", panel_style(fill.lightened(0.08), GOLD, 10, 1))
	hit.add_theme_stylebox_override("pressed", panel_style(fill.darkened(0.08), TEXT, 10, 1))
	hit.pressed.connect(func():
		if sfx_on:
			play_sfx("tap")
		action.call()
	)
	bind_press_juice(hit, hit)
	return hit

func show_data_center() -> void:
	active_menu = "players"
	var content := begin_screen("球星牆", "姓名依收錄資料；OVR 與技能是遊戲設定。", 4)
	for i in mini(public_players.size(), 12):
		var raw: Dictionary = public_players[i]
		content.add_child(name_only_row(to_game_player(raw)))

func league_accent(code: String) -> Color:
	match code:
		"PLG":
			return CYAN
		"TPBL":
			return ORANGE
		"SBL":
			return GOLD
		"WCQ":
			return CYAN
		_:
			return MUTED

func teams_in_league(code: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for team in league_teams:
		if str(team.get("league", "")) == code:
			result.append(team)
	return result

func official_team_tile(team: Dictionary, play_locked: bool, back_filter := "全部") -> Control:
	var rival := official_rival(team)
	var accent := league_accent(str(team.get("league", "")))
	var hit := Button.new()
	hit.text = ""
	hit.custom_minimum_size = Vector2(0, 58)
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", panel_style(Color(0.05, 0.08, 0.12, 0.72), accent.darkened(0.25), 12, 1))
	hit.add_theme_stylebox_override("hover", panel_style(Color(0.08, 0.11, 0.16, 0.4), accent, 12, 2))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(0.04, 0.06, 0.09, 0.8), TEXT, 12, 1))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	hit.add_child(row)
	row.add_child(team_logo_rect(str(rival.get("team_id", team.get("id", ""))), 40, str(rival.get("name", "球"))))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	words.add_child(plain_label(str(rival.get("name", "對手")), 15, TEXT, true))
	var sub := "%s · 戰力 %d · 點進去看陣容" % [rival.get("city", ""), int(rival.get("rating", 70))]
	if play_locked:
		sub = "%s · 尚未能打 · 仍可看陣容學組隊" % rival.get("city", "")
	words.add_child(plain_label(sub, 11, MUTED))
	hit.pressed.connect(func():
		play_sfx("tap")
		open_sub(func(): show_team_overview(back_filter), func(): show_team_profile(team, back_filter))
	)
	bind_press_juice(hit, hit)
	return hit

func league_column(code: String) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	var locked := code != "SBL" and not league_open(code)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	head.add_child(plain_label(code, 18, league_accent(code), true))
	head.add_child(plain_label("未解鎖 · 可看名單" if locked else "%d 隊" % teams_in_league(code).size(), 12, MUTED))
	for team in teams_in_league(code):
		box.add_child(official_team_tile(team, locked, code))
	return box

func name_only_row(player: Dictionary, index := -1) -> PanelContainer:
	var shown := effective_ovr(player, index) if index >= 0 else int(player.get("ovr", 70))
	var miss := index >= 0 and position_mismatch_penalty(player, index) > 0
	var accent := RED if miss else ovr_frame_color(int(player.get("ovr", 70)))
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, body_row_h())
	row.add_theme_stylebox_override("panel", panel_style(Color("0d1c2bed"), accent.darkened(0.15), 10, 2))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(padded(line, 8))
	line.add_child(simple_bust(player, 36))
	line.add_child(pos_chip(player, true))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	words.add_child(fit_label(str(player.get("name", "球員")), 16, TEXT, true))
	words.add_child(fit_label("%s · %s" % [identity_label(player), player.get("skill_name", "即戰力")], 11, MUTED))
	line.add_child(plain_label("OVR %d" % shown, 15, accent, true, HORIZONTAL_ALIGNMENT_RIGHT))
	return row

func clickable_name_row(player: Dictionary, action: Callable, index := -1) -> Control:
	var row := name_only_row(player, index)
	if not action.is_valid():
		return row
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", panel_style(Color(1, 1, 1, 0.08), GOLD, 10, 0))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(1, 1, 1, 0.12), TEXT, 10, 0))
	hit.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	row.add_child(hit)
	bind_press_juice(row, hit)
	return row

func opponent_club(opponent: Dictionary) -> Dictionary:
	var tid := str(opponent.get("team_id", opponent.get("id", "")))
	if tid.is_empty():
		return {}
	var club := find_league_team(tid)
	if not club.is_empty():
		return club
	return national_team_by_id(tid)

func opponent_starting_five(opponent: Dictionary) -> Array[Dictionary]:
	# 優先使用本場對手複本，讓難度加成後的 OVR 顯示在陣容與比賽中；
	# 沒有名單時才回退到聯盟原始球隊資料。
	var source_players: Array = opponent.get("players", [])
	if source_players.is_empty():
		var team := opponent_club(opponent)
		source_players = team.get("players", [])
	var pool: Array[Dictionary] = []
	for item in source_players:
		if item is Dictionary:
			pool.append(to_game_player(item))
	var picked: Array[Dictionary] = []
	var used: Dictionary = {}
	var foreign_count := 0
	for pos in ["PG", "SG", "SF", "PF", "C"]:
		var best_i := -1
		var best_ovr := -1
		for i in pool.size():
			if used.has(i):
				continue
			if is_foreigner(pool[i]) and foreign_count >= foreigner_oncourt_limit():
				continue
			if str(pool[i].get("pos", pool[i].get("position", ""))) != pos:
				continue
			var ovr := int(pool[i].get("ovr", 0))
			if ovr > best_ovr:
				best_ovr = ovr
				best_i = i
		if best_i >= 0:
			used[best_i] = true
			picked.append(pool[best_i])
			if is_foreigner(pool[best_i]):
				foreign_count += 1
	while picked.size() < 5:
		var best_i := -1
		var best_ovr := -1
		for i in pool.size():
			if used.has(i):
				continue
			if is_foreigner(pool[i]) and foreign_count >= foreigner_oncourt_limit():
				continue
			var ovr := int(pool[i].get("ovr", 0))
			if ovr > best_ovr:
				best_ovr = ovr
				best_i = i
		if best_i < 0:
			break
		used[best_i] = true
		picked.append(pool[best_i])
		if is_foreigner(pool[best_i]):
			foreign_count += 1
	return picked

func fill_scroll_body(content: Control) -> void:
	# Let short pages keep their natural height rather than stretching every card.
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if is_handheld() else Control.SIZE_EXPAND_FILL


func match_prep_roster_col(title: String, players: Array, accent: Color, on_player: Callable, footer_label: String, footer_action: Callable, start_index := -1, subtitle := "") -> Control:
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.clip_contents = false
	shell.add_theme_stylebox_override("panel", panel_style(Color("0a1622e8"), accent.darkened(0.2), 16, 1))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	shell.add_child(padded(box, 8))
	box.add_child(plain_label(title, 13, accent, true))
	if not subtitle.is_empty():
		box.add_child(plain_label(subtitle, 11, MUTED, true))
	if players.is_empty():
		box.add_child(wrap_label("這場還沒有公開先發名單。", 12, MUTED, false))
	else:
		var slot := start_index
		for who in players:
			if not (who is Dictionary):
				continue
			var player: Dictionary = who
			var idx := slot
			box.add_child(clickable_name_row(player, func(): on_player.call(player), idx))
			if slot >= 0:
				slot += 1
	if not footer_label.is_empty() and footer_action.is_valid():
		box.add_child(action_button(footer_label, Color("254e6b"), footer_action, Vector2(0, 36)))
	return shell

func show_league_overview() -> void:
	show_team_overview("全部")

func show_team_overview(filter: String) -> void:
	active_menu = "league"
	var content := begin_screen("聯盟", "還沒解鎖也能點球隊看陣容，學怎麼組隊。", 4)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	content.add_child(filters)
	filters.add_child(action_button("全部", TAIWAN_BLUE if filter == "全部" else Color("254e6b"), func(): show_team_overview("全部"), Vector2(0, 44)))
	filters.add_child(action_button("SBL", TAIWAN_BLUE if filter == "SBL" else Color("254e6b"), func(): show_team_overview("SBL"), Vector2(0, 44)))
	filters.add_child(action_button("PLG", TAIWAN_BLUE if filter == "PLG" else Color("254e6b"), func(): show_team_overview("PLG"), Vector2(0, 44)))
	filters.add_child(action_button("TPBL", TAIWAN_BLUE if filter == "TPBL" else Color("254e6b"), func(): show_team_overview("TPBL"), Vector2(0, 44)))
	var intl := HBoxContainer.new()
	intl.add_theme_constant_override("separation", 8)
	content.add_child(intl)
	intl.add_child(action_button("東超", Color("254e6b") if filter != "EASL" else TAIWAN_BLUE, func():
		show_team_overview("EASL")
	, Vector2(0, 44)))
	intl.add_child(action_button("BCL", Color("254e6b") if filter != "BCL" else TAIWAN_BLUE, func():
		show_team_overview("BCL")
	, Vector2(0, 44)))
	intl.add_child(action_button("世界盃", TAIWAN_BLUE if filter == "世界盃" else Color("254e6b"), func(): show_team_overview("世界盃"), Vector2(0, 44)))
	intl.add_child(action_button("瓊斯盃", TAIWAN_BLUE if filter == "瓊斯盃" else Color("254e6b"), func(): show_team_overview("瓊斯盃"), Vector2(0, 44)))
	intl.add_child(action_button("中華隊", TAIWAN_BLUE if filter == "中華隊" else Color("254e6b"), func(): show_team_overview("中華隊"), Vector2(0, 44)))
	if filter == "世界盃":
		if not extra_can_play("wcq"):
			content.add_child(pending_unlock_box("NT$100", "還能看積分與賽程，解鎖後才能代表出賽"))
		content.add_child(extra_event_preview_panel("wcq"))
		return
	if filter == "瓊斯盃":
		if not extra_can_play("jones"):
			content.add_child(pending_unlock_box("NT$60", "還能看隊伍與賽程，解鎖後才能代表出賽"))
		content.add_child(extra_event_preview_panel("jones"))
		return
	if filter == "中華隊":
		if not extra_can_play("wcq"):
			content.add_child(pending_unlock_box("NT$100", "還能看中華台北／中華藍白賽程"))
		content.add_child(national_schedule_panel())
		return
	if filter == "EASL" or filter == "BCL":
		if not league_open(filter):
			content.add_child(pending_unlock_box("NT$100", "東超與 BCL 一起解鎖。下面仍可看參賽隊伍"))
		content.add_child(international_team_list(filter))
		return
	if filter == "全部":
		content.add_child(standings_panel())
		var columns := HBoxContainer.new()
		columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_theme_constant_override("separation", 12)
		content.add_child(columns)
		columns.add_child(league_column("SBL"))
		columns.add_child(league_column("PLG"))
		columns.add_child(league_column("TPBL"))
		return
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	content.add_child(list)
	var shown := 0
	for team in league_teams:
		if str(team.get("league", "")) != filter and not (filter in ["EASL", "BCL"] and str(team.get("league", "")) in ["PLG", "TPBL"]):
			continue
		list.add_child(official_team_tile(team, filter in ["PLG", "TPBL"] and not league_open(filter), filter))
		shown += 1
	if shown == 0:
		content.add_child(label("還沒有對手資料", 14, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))

func world_cup_panel() -> Control:
	return extra_event_preview_panel("wcq")
	# 舊版真實賽果資料保留在存檔來源，但不在遊戲畫面呈現。
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 8)
	box.add_child(callout(str(world_cup_meta.get("title", "世界盃資格賽")), str(world_cup_meta.get("blurb", "")), GOLD))
	var table := PanelContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_stylebox_override("panel", glass_style(16))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	table.add_child(padded(inner, 12))
	inner.add_child(label(str(world_cup_meta.get("round", "B 組")) + " 積分表", 18, GOLD, true))
	inner.add_child(label("Window 1–3 預告。所有隊伍目前 0－0，點列看參賽名單。", 12, MUTED))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	inner.add_child(header)
	header.add_child(standings_cell("#", 36, MUTED))
	header.add_child(standings_cell("球隊", 0, MUTED, true))
	header.add_child(standings_cell("勝敗", 72, MUTED))
	header.add_child(standings_cell("勝場差", 72, MUTED))
	header.add_child(standings_cell("近5", 88, MUTED))
	header.add_child(standings_cell("下一場", 140, MUTED))
	var rows: Array = world_cup_meta.get("standings", [])
	for i in rows.size():
		if not (rows[i] is Dictionary):
			continue
		inner.add_child(world_cup_standing_row(i + 1, rows[i]))
	box.add_child(table)
	box.add_child(label("中華台北賽程", 16, GOLD, true))
	for game in world_cup_meta.get("games", []):
		if not (game is Dictionary):
			continue
		var home := str(game.get("home", ""))
		var away := str(game.get("away", ""))
		if home != "中華台北" and away != "中華台北":
			continue
		var line := "%s  W%d  %s %d－%d %s" % [str(game.get("date", "")), int(game.get("window", 0)), home, int(game.get("hs", 0)), int(game.get("as", 0)), away]
		box.add_child(wrap_label(line, 13, TEXT, false))
	box.add_child(label("點球隊看 Window 3 名單", 16, GOLD, true))
	for team in national_teams:
		box.add_child(official_team_tile(team, true, "世界盃"))
	return box

func jones_cup_panel() -> Control:
	return extra_event_preview_panel("jones")
	# 舊版真實賽果資料保留在存檔來源，但不在遊戲畫面呈現。
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	box.add_child(callout(str(jones_cup_meta.get("title", "瓊斯盃")), str(jones_cup_meta.get("blurb", "")), GOLD))
	var table := PanelContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_stylebox_override("panel", glass_style(16))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	table.add_child(padded(inner, 12))
	inner.add_child(label(str(jones_cup_meta.get("round", "男子組")) + " 最終名次", 18, GOLD, true))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	inner.add_child(header)
	header.add_child(standings_cell("#", 36, MUTED))
	header.add_child(standings_cell("球隊", 0, MUTED, true))
	header.add_child(standings_cell("勝敗", 72, MUTED))
	header.add_child(standings_cell("名次", 72, MUTED))
	header.add_child(standings_cell("近況", 88, MUTED))
	var rows: Array = jones_cup_meta.get("standings", [])
	for i in rows.size():
		if rows[i] is Dictionary:
			inner.add_child(event_standing_row(i + 1, rows[i], GOLD if str(rows[i].get("name", "")).begins_with("中華") else CYAN))
	box.add_child(table)
	box.add_child(label("中華藍／白賽程", 16, GOLD, true))
	for game in jones_cup_meta.get("games", []):
		if not (game is Dictionary):
			continue
		var home := str(game.get("home", ""))
		var away := str(game.get("away", ""))
		if not home.begins_with("中華") and not away.begins_with("中華"):
			continue
		box.add_child(wrap_label("%s  %s  %s %d－%d %s" % [str(game.get("date", "")), str(game.get("note", "")), home, int(game.get("hs", 0)), int(game.get("as", 0)), away], 13, TEXT, false))
	box.add_child(label("參賽隊伍", 16, GOLD, true))
	for team in extra_event_data("jones").get("teams", []):
		if team is Dictionary:
			box.add_child(fit_label("%s · 戰力 %d" % [str(team.get("name", "")), int(team.get("rating", 75))], 14, TEXT, true))
	return box

func national_schedule_panel() -> Control:
	var preview := VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_theme_constant_override("separation", 8)
	preview.add_child(callout("中華隊預告", "資格賽與瓊斯盃都尚未開打；這裡只顯示預告，不沿用真實賽果。", GOLD))
	preview.add_child(extra_event_preview_panel("wcq"))
	preview.add_child(extra_event_preview_panel("jones"))
	return preview
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	box.add_child(callout("中華隊賽程", "世界盃資格賽中華台北，加上瓊斯盃中華藍／白。", GOLD))
	box.add_child(label("世界盃資格賽 · 中華台北", 16, GOLD, true))
	for game in world_cup_meta.get("games", []):
		if not (game is Dictionary):
			continue
		var home := str(game.get("home", ""))
		var away := str(game.get("away", ""))
		if home != "中華台北" and away != "中華台北":
			continue
		box.add_child(wrap_label("%s  W%d  %s %d－%d %s" % [str(game.get("date", "")), int(game.get("window", 0)), home, int(game.get("hs", 0)), int(game.get("as", 0)), away], 13, TEXT, false))
	box.add_child(label("瓊斯盃 · 中華藍／白", 16, GOLD, true))
	for game in jones_cup_meta.get("games", []):
		if not (game is Dictionary):
			continue
		var home := str(game.get("home", ""))
		var away := str(game.get("away", ""))
		if not home.begins_with("中華") and not away.begins_with("中華"):
			continue
		box.add_child(wrap_label("%s  %s  %s %d－%d %s" % [str(game.get("date", "")), str(game.get("note", "")), home, int(game.get("hs", 0)), int(game.get("as", 0)), away], 13, TEXT, false))
	box.add_child(label("世界盃 Window 3 中華台北 12 人", 16, GOLD, true))
	var taipei := national_team_by_id("nt_taipei")
	if not taipei.is_empty():
		box.add_child(official_team_tile(taipei, true, "世界盃"))
	return box

func international_team_list(filter: String) -> Control:
	return extra_event_preview_panel("bcl" if filter == "BCL" else "easl")

func extra_event_preview_panel(event_id: String) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	var run := extra_run(event_id)
	var table := PanelContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_stylebox_override("panel", glass_style(16))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	table.add_child(padded(inner, 12))
	inner.add_child(label("累計對戰紀錄", 18, GOLD, true))
	inner.add_child(label("僅統計你的出賽，重挑戰保留戰績；點其他球隊可查看完整陣容。", 12, MUTED))
	if bool(run.get("legacy_record", false)):
		inner.add_child(label("舊存檔僅能還原當時連勝，早期敗場與對手未保存。", 12, MUTED))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	inner.add_child(header)
	header.add_child(standings_cell("#", 36, MUTED))
	var logo_space := Control.new()
	logo_space.custom_minimum_size.x = 28
	header.add_child(logo_space)
	header.add_child(standings_cell("球隊", 0, MUTED, true))
	header.add_child(standings_cell("勝敗", 72, MUTED))
	header.add_child(standings_cell("近況", 100, MUTED))
	header.add_child(standings_cell("下一場", 100, MUTED))
	header.add_child(standings_cell("陣容", 64, MUTED))
	var rows := extra_preview_standings(event_id)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var accent := GOLD if bool(row.get("is_user", false)) else CYAN
		inner.add_child(extra_preview_standing_row(i + 1, row, accent, event_id))
	box.add_child(table)
	var history: Array = run.get("history", [])
	if not history.is_empty():
		box.add_child(label("最近比賽", 16, GOLD, true))
		for i in range(history.size() - 1, maxi(-1, history.size() - 6), -1):
			var match_row: Dictionary = history[i]
			box.add_child(label("%s  %d－%d  vs %s" % ["勝" if bool(match_row.get("won", false)) else "敗", int(match_row.get("for", 0)), int(match_row.get("against", 0)), str(match_row.get("opponent", "對手"))], 14, TEXT))
	var queue: Array = run.get("queue", [])
	if not queue.is_empty():
		box.add_child(label("本輪剩餘賽程", 16, GOLD, true))
		for i in queue.size():
			box.add_child(label("第 %d 場 · %s vs %s" % [int(run.get("wins", 0)) + i + 1, club_display_name(), str(queue[i].get("name", "對手"))], 14, TEXT))
	elif history.is_empty():
		box.add_child(label("參賽後產生你的賽程。", 14, MUTED))
	return box

func extra_preview_standing_row(rank: int, row: Dictionary, accent: Color, event_id := "") -> Control:
	var line := HBoxContainer.new()
	line.custom_minimum_size = Vector2(0, 38)
	line.add_theme_constant_override("separation", 8)
	line.add_child(standings_cell(str(rank), 36, accent))
	line.add_child(team_logo_rect(str(row.get("id", "")), 28, str(row.get("name", "球隊"))))
	line.add_child(standings_cell(str(row.get("name", "球隊")), 0, accent, true))
	line.add_child(standings_cell("%d－%d" % [int(row.get("w", 0)), int(row.get("l", 0))], 72, TEXT))
	line.add_child(standings_cell(str(row.get("last5", "—")), 100, MUTED))
	line.add_child(standings_cell(str(row.get("next", "—")), 100, MUTED))
	line.add_child(standings_cell("—" if bool(row.get("is_user", false)) else "查看 ›", 64, MUTED if bool(row.get("is_user", false)) else CYAN))
	if bool(row.get("is_user", false)) or event_id.is_empty():
		return line
	var hit := Button.new()
	hit.name = "ExtraTeam_" + str(row.get("id", "unknown"))
	hit.text = ""
	hit.custom_minimum_size = Vector2(0, 44 if is_handheld() else 38)
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.tooltip_text = "點擊查看 %s 完整陣容" % str(row.get("name", "球隊"))
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", panel_style(Color(0.05, 0.13, 0.17, 0.55), CYAN, 8, 1))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(0.04, 0.08, 0.12, 0.72), TEXT, 8, 1))
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 4
	line.offset_right = -4
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.add_child(line)
	var picked: Dictionary = row.duplicate(true)
	hit.pressed.connect(func():
		play_sfx("tap")
		show_extra_team_roster(picked, event_id)
	)
	bind_press_juice(hit, hit)
	return hit

func event_standing_row(rank: int, row: Dictionary, accent: Color) -> Control:
	var line := HBoxContainer.new()
	line.custom_minimum_size = Vector2(0, 36)
	line.add_theme_constant_override("separation", 8)
	line.add_child(standings_cell(str(rank), 36, accent))
	line.add_child(team_logo_rect(national_logo_id(str(row.get("id", "")), str(row.get("name", ""))), 28, str(row.get("name", "球"))))
	line.add_child(standings_cell(str(row.get("name", "球隊")), 0, TEXT if accent != GOLD else GOLD, true))
	line.add_child(standings_cell("%d-%d" % [int(row.get("w", 0)), int(row.get("l", 0))], 72, TEXT))
	line.add_child(standings_cell(str(row.get("gb", "—")), 72, MUTED))
	line.add_child(standings_cell(str(row.get("last5", "")), 88, MUTED))
	return line

func world_cup_standing_row(rank: int, row: Dictionary) -> Control:
	var accent := GOLD if str(row.get("id", "")) == "nt_taipei" else CYAN
	var hit := Button.new()
	hit.text = ""
	hit.custom_minimum_size = Vector2(0, 44)
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", panel_style(Color(0.12, 0.1, 0.05, 0.55) if accent == GOLD else Color(0.05, 0.08, 0.12, 0.72), accent.darkened(0.2), 10, 1 if accent == GOLD else 0))
	hit.add_theme_stylebox_override("hover", panel_style(Color(0.08, 0.11, 0.16, 0.4), accent, 10, 1))
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8
	line.offset_right = -8
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 8)
	hit.add_child(line)
	line.add_child(standings_cell(str(rank), 36, accent))
	line.add_child(team_logo_rect(str(row.get("id", "")), 28, str(row.get("name", "球"))))
	line.add_child(standings_cell(str(row.get("name", "球隊")), 0, TEXT if accent != GOLD else GOLD, true))
	line.add_child(standings_cell("%d-%d" % [int(row.get("w", 0)), int(row.get("l", 0))], 72, TEXT))
	line.add_child(standings_cell(str(row.get("gb", "—")), 72, MUTED))
	line.add_child(standings_cell(str(row.get("last5", "")), 88, MUTED))
	line.add_child(standings_cell(str(row.get("next", "—")), 140, MUTED))
	var tid := str(row.get("id", ""))
	hit.pressed.connect(func():
		play_sfx("tap")
		var team := national_team_by_id(tid)
		if not team.is_empty():
			open_sub(func(): show_team_overview("世界盃"), func(): show_team_profile(team, "世界盃"))
	)
	bind_press_juice(hit, hit)
	return hit

func standings_panel() -> Control:
	if league_table.is_empty():
		reset_league_table()
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", glass_style(16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	shell.add_child(padded(box, 12))
	box.add_child(label("%s 積分表" % current_league, 18, GOLD, true))
	box.add_child(label("勝－敗 · 勝場差 · 近五場 · 下一場。點列看名單。", 12, MUTED))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	header.add_child(standings_cell("#", 36, MUTED))
	header.add_child(standings_cell("球隊", 0, MUTED, true))
	header.add_child(standings_cell("勝敗", 72, MUTED))
	header.add_child(standings_cell("勝場差", 72, MUTED))
	header.add_child(standings_cell("近5", 88, MUTED))
	header.add_child(standings_cell("下一場", 140, MUTED))
	var rows := standings_rows()
	for i in rows.size():
		box.add_child(standings_row_button(i + 1, rows[i]))
	return shell

func standings_cell(text_value: String, width: int, color: Color, expand := false) -> Label:
	var node := fit_label(text_value, 12, color, true)
	if expand:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif width > 0:
		node.size_flags_horizontal = Control.SIZE_FILL
		node.custom_minimum_size = Vector2(width, 0)
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node

func standings_next_name(row: Dictionary) -> String:
	if bool(row.get("self", false)):
		if schedule_index >= 0 and schedule_index < season_schedule.size():
			var game: Dictionary = season_schedule[schedule_index]
			var team: Dictionary = game.get("team", {})
			return str(team.get("name", "—"))
		return "—"
	var names: Array[String] = []
	for other in standings_rows():
		if str(other.get("team_id", "")) == str(row.get("team_id", "")):
			continue
		names.append(str(other.get("name", "對手")))
	if names.is_empty():
		return "—"
	return names[absi(str(row.get("team_id", "")).hash() + schedule_index) % names.size()]

func standings_row_button(rank: int, row: Dictionary) -> Control:
	var self_row := bool(row.get("self", false))
	var accent := GOLD if self_row else CYAN
	var hit := Button.new()
	hit.text = ""
	hit.custom_minimum_size = Vector2(0, 44)
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", panel_style(Color(0.12, 0.1, 0.05, 0.55) if self_row else Color(0.05, 0.08, 0.12, 0.72), accent.darkened(0.2), 10, 1 if self_row else 0))
	hit.add_theme_stylebox_override("hover", panel_style(Color(0.08, 0.11, 0.16, 0.4), accent, 10, 1))
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8
	line.offset_right = -8
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 8)
	hit.add_child(line)
	line.add_child(standings_cell(str(rank), 36, accent))
	var logo_id := ensure_club_logo_id() if self_row else str(row.get("team_id", ""))
	line.add_child(team_logo_rect(logo_id, 28, str(row.get("name", "球"))))
	line.add_child(standings_cell(str(row.get("name", "球隊")), 0, TEXT if not self_row else GOLD, true))
	line.add_child(standings_cell("%d-%d" % [int(row.get("w", 0)), int(row.get("l", 0))], 72, TEXT))
	line.add_child(standings_cell(games_behind_text(row), 72, MUTED))
	line.add_child(standings_cell(last5_text(row), 88, MUTED))
	line.add_child(standings_cell(standings_next_name(row), 140, MUTED))
	var tid := str(row.get("team_id", ""))
	hit.pressed.connect(func():
		play_sfx("tap")
		if self_row:
			show_roster()
			return
		var team := find_league_team(tid)
		if team.is_empty():
			flash_notice("這支球隊還沒有公開名單")
			return
		open_sub(show_league_overview, func(): show_team_profile(team))
	)
	bind_press_juice(hit, hit)
	return hit

func find_league_team(tid: String) -> Dictionary:
	for team in league_teams:
		if str(team.get("id", "")) == tid:
			return team
	return {}

func show_team_profile(team: Dictionary, back_filter := "全部") -> void:
	active_menu = "league"
	var rival := official_rival(team)
	var lg := str(team.get("league", ""))
	var play_locked := (lg in ["PLG", "TPBL"] and not league_open(lg)) or lg == "WCQ"
	var content := begin_screen(str(rival.get("name", "對手")), "%s · %s · 戰力 %d" % [lg, rival.get("city", ""), int(rival.get("rating", 70))], 4)
	if lg == "WCQ":
		var src := str(team.get("source", ""))
		if not src.is_empty():
			content.add_child(callout("名單來源", src, GOLD))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	content.add_child(head)
	head.add_child(team_logo_rect(str(team.get("id", "")), 64, str(rival.get("name", "球"))))
	var head_words := VBoxContainer.new()
	head_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_words.add_theme_constant_override("separation", 2)
	head.add_child(head_words)
	head_words.add_child(label("%s · 官方隊徽" % rival.get("name", "對手"), 16, GOLD, true))
	head_words.add_child(label("看這隊怎麼排身份與出身，回去組自己的。" if play_locked else "公開名單 · 點列對照組隊", 12, MUTED))
	var players: Array = team.get("players", [])
	var roster: Array[Dictionary] = []
	for raw in players:
		if raw is Dictionary:
			roster.append(to_game_player(raw))
	if lg == "WCQ":
		content.add_child(callout("國家隊名單", "這是資格賽預告名單，給你對照組隊。例行賽不打這些國家隊。", CYAN))
	elif play_locked:
		content.add_child(callout("尚未能打 %s" % lg, "冠軍前先看陣容。外援、外籍生、同出身人數就是組隊線索。", ORANGE))
	content.add_child(callout("陣容", team_roster_build_hint(roster), GOLD))
	for who in roster:
		content.add_child(name_only_row(who))
	if roster.is_empty():
		content.add_child(label("這隊還沒有公開名單", 14, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))

func team_roster_build_hint(roster: Array) -> String:
	if roster.is_empty():
		return "這隊還沒有公開球員。"
	var origins := {}
	var foreign := 0
	var students := 0
	for who in roster:
		if not (who is Dictionary):
			continue
		var player: Dictionary = who
		if is_foreigner(player):
			foreign += 1
		if is_foreign_student(player):
			students += 1
		var origin := origin_id(player)
		if origin.is_empty():
			continue
		origins[origin] = int(origins.get(origin, 0)) + 1
	var top_origin := ""
	var top_n := 0
	for key in origins.keys():
		if int(origins[key]) > top_n:
			top_n = int(origins[key])
			top_origin = str(key)
	var origin_line := "出身分散"
	if not top_origin.is_empty():
		origin_line = "%s %d 人" % [combo_origin_label(top_origin), top_n]
	return "共 %d 人 · %s · 外援 %d · 外籍生 %d。同出身湊 5／7／10／12 人會加隊伍 OVR。" % [roster.size(), origin_line, foreign, students]

func real_roster_row(raw: Dictionary) -> PanelContainer:
	var accent := identity_accent(raw)
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 62)
	row.add_theme_stylebox_override("panel", panel_style(Color("0d1c2bed"), accent.darkened(0.4), 10, 1))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(padded(line, 7))
	line.add_child(player_portrait(raw, Vector2(52, 52)))
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(label(str(raw.get("name", "球員")), 15, TEXT, true))
	name_box.add_child(label("%s · %s · %s" % [raw.get("position", "SG"), identity_label(raw), raw.get("origin_team_id", "")], 11, MUTED))
	line.add_child(name_box)
	line.add_child(label("OVR %d" % int(raw.get("ovr", 70)), 15, accent, true, HORIZONTAL_ALIGNMENT_RIGHT))
	line.add_child(label("潛力 %d" % int(raw.get("potential", 75)), 12, GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT))
	return row

func team_profile_text(team_id: String) -> String:
	match team_id:
		"fubon": return "成熟的首都球隊架構，重視半場執行與側翼深度。"
		"pilots": return "快速轉換與後場火力為核心，適合拉高比賽節奏。"
		"ghosthawks": return "強調速度與壓迫感的南部勁旅，防守輪轉是關鍵。"
		"yankey": return "年輕球員與潛力資產並存，需要建立戰術身份。"
		"dreamers": return "進攻天賦充足，需要平衡球權與防守。"
		"lioneers": return "主場氣勢與後場火力並存，適合培養新核心。"
		"aquas": return "海港城市的韌性球隊，內線與防守是競爭力來源。"
		_: return "這是一支等待你定義未來的台灣籃球隊。"

func all_league_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for team in league_teams:
		for raw in team.get("players", []):
			if raw is Dictionary:
				result.append(raw.duplicate(true))
	return result

func market_player_pool() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw in all_league_players():
		var player := to_game_player(raw)
		var key := str(player.get("id", player.get("name", "")))
		if key.is_empty() or seen.has(key):
			continue
		# Show the complete 200-player catalog. Only gold and diamond cards stay out.
		if player_tier_key(player) in ["gold", "diamond"]:
			continue
		# OVR 80+ cards are scout exclusives; they never leak into free agency
		# or trade listings.
		if int(player.get("ovr", 70)) >= 80:
			continue
		# Do not offer a card that is already on this roster, in the vault, or
		# assigned to another saved team. This prevents confusing self-trades.
		if team_has_player(player):
			continue
		seen[key] = true
		result.append(player)
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(a.get("ovr", 70)) > int(b.get("ovr", 70))
	)
	return result

func market_matches_filter(player: Dictionary) -> bool:
	if not market_filter_pos.is_empty() and market_filter_pos not in player_pos_list(player):
		return false
	if not market_filter_origin.is_empty() and origin_id(player) != market_filter_origin:
		return false
	var ovr := int(player.get("ovr", 70))
	if market_filter_ovr > 0 and ovr < market_filter_ovr:
		return false
	if market_filter_ovr < 0 and ovr > absi(market_filter_ovr):
		return false
	return true

func market_origin_options(pool: Array[Dictionary]) -> Array[String]:
	var seen: Dictionary = {}
	var ids: Array[String] = []
	for player in pool:
		var origin := origin_id(player)
		if origin.is_empty() or seen.has(origin):
			continue
		seen[origin] = true
		ids.append(origin)
	ids.sort_custom(func(a, b): return team_short_name(a) < team_short_name(b))
	return ids

func market_filters_clear() -> bool:
	return market_filter_pos.is_empty() and market_filter_origin.is_empty() and market_filter_ovr == 0

func market_filter_bar(pool: Array[Dictionary], refresh: Callable) -> Control:
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	row.add_child(label("篩選", 11, MUTED, true))
	row.add_child(roster_filter_chip("位置", market_filter_kind == "pos", func():
		market_filter_kind = "pos"
		refresh.call()
	))
	row.add_child(roster_filter_chip("出身", market_filter_kind == "origin", func():
		market_filter_kind = "origin"
		refresh.call()
	))
	row.add_child(roster_filter_chip("OVR", market_filter_kind == "ovr", func():
		market_filter_kind = "ovr"
		refresh.call()
	))
	if not market_filters_clear():
		row.add_child(roster_filter_chip("清除", false, func():
			market_filter_pos = ""
			market_filter_origin = ""
			market_filter_ovr = 0
			refresh.call()
		))
	if market_filter_kind == "origin":
		row.add_child(roster_filter_chip("全部", market_filter_origin.is_empty(), func():
			market_filter_origin = ""
			refresh.call()
		))
		for origin: String in market_origin_options(pool):
			var oid: String = origin
			row.add_child(roster_filter_chip(team_short_name(oid), market_filter_origin == oid, func():
				market_filter_origin = "" if market_filter_origin == oid else oid
				refresh.call()
			))
	elif market_filter_kind == "ovr":
		row.add_child(roster_filter_chip("全部", market_filter_ovr == 0, func():
			market_filter_ovr = 0
			refresh.call()
		))
		for spec: Array in [[86, "86+"], [81, "81+"], [76, "76+"], [71, "71+"], [-70, "70↓"]]:
			var want: int = int(spec[0])
			var label_txt: String = str(spec[1])
			row.add_child(roster_filter_chip(label_txt, market_filter_ovr == want, func():
				market_filter_ovr = 0 if market_filter_ovr == want else want
				refresh.call()
			))
	else:
		row.add_child(roster_filter_chip("全部", market_filter_pos.is_empty(), func():
			market_filter_pos = ""
			refresh.call()
		))
		for pos: String in ["PG", "SG", "SF", "PF", "C"]:
			var key: String = pos
			row.add_child(roster_filter_chip(pos, market_filter_pos == key, func():
				market_filter_pos = "" if market_filter_pos == key else key
				refresh.call()
			))
	return row

func trade_fee_for(player: Dictionary) -> int:
	return maxi(70, int(float(published_salary(player)) * 0.35))

func market_page_slice(filtered: Array[Dictionary], shown_n: int) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for i in mini(shown_n, filtered.size()):
		visible.append(filtered[i])
	return visible

func market_more_button(remain: int, action: Callable) -> Button:
	var more := action_button("再顯示 12 人（還有 %d 人）" % remain, Color("254e6b"), action, Vector2(0, 44))
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return more

func market_card_width() -> int:
	# lobby_player_card applies the shared 75% compact scale. Keep the source
	# width large enough for readable names on desktop while preserving the
	# tighter six-column layout used by phone scout offers.
	return UI_MARKET_CARD_WIDTH_PHONE if is_handheld() else UI_MARKET_CARD_WIDTH_DESKTOP

func market_player_grid(players: Array[Dictionary], footer_for: Callable, on_press: Callable) -> Control:
	var grid := GridContainer.new()
	grid.columns = maxi(2, mini(5, int(usable_view().x / 180.0))) if is_handheld() else (5 if compact_phone() else 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var card_w := market_card_width()
	for player: Dictionary in players:
		var captured: Dictionary = player
		var footer := ""
		if footer_for.is_valid():
			footer = str(footer_for.call(captured))
		var slot := CenterContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_child(lobby_player_card(captured, false, -1, false, card_w, func():
			on_press.call(captured)
		, -1, footer))
		grid.add_child(slot)
	return grid

func show_market() -> void:
	active_menu = "market"
	var content := begin_screen("市場", "球探用球探點 · 簽約／交易用資金 · 年薪另計薪資帽", 4)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for entry in [
		["球探", "隨機卡片 · %d 球探點" % scout_points, show_gacha_market],
		["交易", "可多換一 · 薪資條件與交易費", show_trade_market],
		["自由市場", "資金付簽約費 · 年薪計入薪資帽", show_free_agent_market],
		["選秀", "2026 新人 · " + ("已開放" if draft_eligible() else "完整賽季後開放"), show_draft_market]
	]:
		var destination: Callable = entry[2]
		var button := market_entry_card(str(entry[0]), str(entry[1]), CYAN, func(): open_sub(show_market, destination))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	content.add_child(label("注意：任何管道拿到同名重複卡，都會轉為黃金並跳出提示；原卡保留。", 12, MUTED))

func market_entry_card(title: String, subtitle: String, accent: Color, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(258, 105)
	button.text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", panel_style(Color("0d1c2bed"), accent.darkened(0.35), 15, 1))
	button.add_theme_stylebox_override("hover", panel_style(Color("172e40f5"), accent, 15, 2))
	button.add_theme_stylebox_override("pressed", panel_style(Color("213f50f5"), TEXT, 15, 2))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	var margin := padded(box, 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(margin)
	box.add_child(label(title, 17, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(label(subtitle, 11, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	button.pressed.connect(action)
	return button

func show_trade_market(expand := false) -> void:
	active_menu = "market"
	if expand:
		trade_list_shown += 12
	else:
		trade_list_shown = 12
	var content := begin_screen("交易", "可多換一。點想要的球員會跳出視窗，再選一張或以上我方卡。合計年薪必須 ≥ 換入年薪。", 4)
	content.add_child(callout("交易規則", "可一換一或多換一：換入一人，被選中的我方球員都會離開。合計年薪必須 ≥ 換入年薪。對手比賽仍用原陣容。不含黃金卡或鑽石卡。", ORANGE))
	var pool := market_player_pool()
	content.add_child(market_filter_bar(pool, func(): show_trade_market()))
	var filtered: Array[Dictionary] = []
	for player in pool:
		if market_matches_filter(player):
			filtered.append(player)
	var shown := mini(trade_list_shown, filtered.size())
	var visible: Array[Dictionary] = []
	for i in shown:
		visible.append(filtered[i])
	if filtered.is_empty():
		content.add_child(callout("沒有符合條件的球員", "請清除篩選，或目前球員已在你的名單／保管箱。", MUTED))
	else:
		content.add_child(label("顯示 %d／%d 人 · 先用上方篩選縮小範圍" % [shown, filtered.size()], 12, MUTED, true, HORIZONTAL_ALIGNMENT_LEFT))
		content.add_child(market_player_grid(visible, func(player: Dictionary):
			return "已擁有" if team_has_player(player) else "交易費 $%d 萬（另計）" % trade_fee_for(player)
		, func(player: Dictionary):
			open_trade_offer(player)
		))
		if shown < filtered.size():
			content.add_child(market_more_button(filtered.size() - shown, func(): show_trade_market(true)))

func show_free_agent_market(expand := false) -> void:
	active_menu = "market"
	if expand:
		fa_list_shown += 12
	else:
		fa_list_shown = 12
	var content := begin_screen("自由市場", "可用資金 $%d 萬 · 簽約費與年薪分開計算" % budget_million, 4)
	content.add_child(callout("自由市場規則", "簽約費從資金扣除；年薪計入薪資帽，不扣黃金或球探點。OVR 80 以上球員只會在球探出現；黃金卡、鑽石卡也不開放簽約。", GREEN))
	var pool := market_player_pool()
	content.add_child(market_filter_bar(pool, func(): show_free_agent_market()))
	var filtered: Array[Dictionary] = []
	for player in pool:
		if market_matches_filter(player):
			filtered.append(player)
	var shown := mini(fa_list_shown, filtered.size())
	var visible := market_page_slice(filtered, shown)
	if filtered.is_empty():
		content.add_child(callout("沒有符合條件的球員", "請清除篩選，或目前球員已在你的名單／保管箱。", MUTED))
	else:
		content.add_child(label("顯示 %d／%d 人 · 先用上方篩選縮小範圍" % [shown, filtered.size()], 12, MUTED, true, HORIZONTAL_ALIGNMENT_LEFT))
		content.add_child(market_player_grid(visible, func(player: Dictionary):
			return "已擁有" if team_has_player(player) else "簽約費 %d萬" % free_agent_signing_fee(player)
		, func(player: Dictionary):
			show_player_sheet(player, func(): show_free_agent_market(), func(): sign_free_agent(player), "確認自由簽約", -1, true)
		))
		if shown < filtered.size():
			content.add_child(market_more_button(filtered.size() - shown, func(): show_free_agent_market(true)))

func show_draft_market() -> void:
	active_menu = "market"
	var content := begin_screen("2026 選秀", "完整賽季含季後賽結束才開放 · 每隊一輪 · 逆戰績順位", 4)
	if not draft_eligible():
		content.add_child(callout("尚未取得選秀資格", "請先打完目前國內聯盟的整個賽季，包括晉級的季後賽。額外比賽不影響選秀資格。", CYAN))
		return
	prepare_draft()
	var position := int(draft_state.get("user_pick", 1))
	var done := bool(draft_state.get("completed", false))
	content.add_child(label("本季第 %d 順位 · %s" % [position, "已完成選秀" if done else "輪到你選擇"], 18, CYAN, true))
	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 8)
	tools_row.add_child(action_button("順位／已選球員", Color("254052"), func(): show_draft_order()))
	tools_row.add_child(action_button("名單來源／規則", Color("254052"), func(): show_guide_sheet("2026 選秀說明", "PLG 25 名、TPBL 30 名、SBL 27 名報名資料，合併同名後 45 人。TPBL 退出但仍列 PLG 報名表者保留。SBL 依兩份公開報導核對，尚待官方表補驗。\n同名球員跨聯盟只保留一張；每個生涯已被任何隊選走者不再出現。先前順位由電腦選擇，後續順位於你選完後完成。\n順位依本季例行賽勝率由低至高，同率比較淨勝分，再同分按隊伍 ID 固定排序。舊存檔若無例行賽快照，會標明採現有積分。\nOVR 68、潛力 82、薪資 100 萬皆為統一遊戲設定；五個細分位置為遊戲配置。未提供新人肖像，名單不冒用其他球員照片。\n選秀不扣黃金或球探點，也沒有選秀費；登錄仍受薪資帽限制，超帽入保管箱。重複卡改發黃金。", CYAN)))
	content.add_child(tools_row)
	if done:
		content.add_child(callout("本季新人", str(draft_state.get("selection", "已完成")), GREEN))
		return
	var prospects := remaining_draft_players()
	if prospects.is_empty():
		content.add_child(callout("本屆名單已選完", "2026 名單沒有剩餘新人；可直接開始下一季，不會補造球員。", MUTED))
		return
	# Text list avoids substituting unrelated portraits for the real registrants.
	for player in prospects:
		var p: Dictionary = player
		var source_pos := str(p.get("draft_source_position", ""))
		var subtitle := "%s · %s\n報名 %s" % [p.get("draft_school", ""), source_pos if not source_pos.is_empty() else "官方位置待補", p.get("draft_leagues", "")]
		content.add_child(market_entry_card(str(p.name), subtitle, CYAN, func():
			show_guide_sheet("選擇 " + str(p.name), subtitle + "\n遊戲設定：OVR 68 · 潛力 82 · 薪資 100 萬。\n" + ("已擁有：確認後轉成 %d 黃金。" % duplicate_gold_for(p) if team_has_player(p) else "確認後取得本季唯一選秀名額。"), CYAN)
			var body := guide_modal.find_child("GuideBody", true, false)
			body.add_child(action_button("確認選秀", CYAN, func(): draft_player(p)))
		))

func draft_eligible() -> bool:
	return current_league in ["SBL", "PLG", "TPBL"] and regular_games >= regular_season_length() and season_phase in ["offseason", "champion"] and not match_rewards_pending

func capture_draft_order() -> void:
	if draft_state.has("order"):
		return
	var order := standings_rows()
	order.sort_custom(func(a: Dictionary, b: Dictionary):
		var aw := int(a.get("w", 0))
		var bw := int(b.get("w", 0))
		var ag := maxi(1, aw + int(a.get("l", 0)))
		var bg := maxi(1, bw + int(b.get("l", 0)))
		if aw * bg != bw * ag:
			return aw * bg < bw * ag
		if int(a.get("pd", 0)) != int(b.get("pd", 0)):
			return int(a.get("pd", 0)) < int(b.get("pd", 0))
		return str(a.get("team_id", "")) < str(b.get("team_id", ""))
	)
	draft_state["order"] = order

func remaining_draft_players() -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for player in DraftCatalog.players():
		if not drafted_prospect_ids.has(str(player.id)):
			players.append(player)
	return players

func draft_ai_pick(team: Dictionary) -> void:
	var remaining := remaining_draft_players()
	if remaining.is_empty():
		return
	# Equal starting ability; deterministic preference cannot reroll on reopening.
	remaining.sort_custom(func(a: Dictionary, b: Dictionary):
		return (str(team.get("team_id", "")) + str(a.id)).sha256_text() < (str(team.get("team_id", "")) + str(b.id)).sha256_text()
	)
	var picked: Dictionary = remaining[0]
	drafted_prospect_ids.append(str(picked.id))
	draft_state["picks"].append({"team":team.get("name", ""), "player":picked.name})

func prepare_draft() -> void:
	if not draft_eligible() or bool(draft_state.get("prepared", false)):
		return
	if not draft_state.has("order"):
		capture_draft_order()
		draft_state["legacy_order"] = true
	draft_state["picks"] = []
	draft_state["prepared"] = true
	for i in draft_state.order.size():
		var team: Dictionary = draft_state.order[i]
		if bool(team.get("self", false)):
			draft_state["user_pick"] = i + 1
			break
		draft_ai_pick(team)
	save_game()

func show_draft_order() -> void:
	var lines: Array[String] = []
	if bool(draft_state.get("legacy_order", false)):
		lines.append("舊存檔無例行賽快照：本次採目前積分排序。")
	var order: Array = draft_state.get("order", [])
	for i in order.size():
		lines.append("%d · %s · %d 勝 %d 敗" % [i + 1, order[i].get("name", ""), int(order[i].get("w", 0)), int(order[i].get("l", 0))])
	for pick in draft_state.get("picks", []):
		lines.append("%s 選擇 %s" % [pick.team, pick.player])
	show_guide_sheet("選秀順位與結果", "\n".join(lines), CYAN)

func close_trade_modal() -> void:
	if is_instance_valid(trade_modal):
		var old := trade_modal
		trade_modal = null
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
	trade_modal = null

func open_trade_offer(player: Dictionary) -> void:
	if team_has_player(player):
		flash_notice("這名球員已在你的名單或保管箱，不能重複交易。")
		return
	trade_incoming = player.duplicate(true)
	trade_out_indices.clear()
	show_trade_offer_modal("")

func toggle_trade_out(index: int) -> void:
	var pos := trade_out_indices.find(index)
	if pos >= 0:
		trade_out_indices.remove_at(pos)
		show_trade_offer_modal("")
		return
	var after := team_players.size() - (trade_out_indices.size() + 1) + 1
	if after < minimum_roster_to_play():
		show_trade_offer_modal("交易後至少要留 7 人，請少選幾名我方球員")
		return
	trade_out_indices.append(index)
	show_trade_offer_modal("")

func trade_outgoing_salary() -> int:
	var total := 0
	for idx in trade_out_indices:
		if idx >= 0 and idx < team_players.size():
			total += published_salary(team_players[idx])
	return total

func trade_outgoing_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for idx in trade_out_indices:
		if idx >= 0 and idx < team_players.size():
			names.append(str(team_players[idx].get("name", "球員")))
	return names

func show_trade_offer_modal(error_text := "") -> void:
	close_trade_modal()
	if trade_incoming.is_empty():
		return
	var incoming: Dictionary = to_game_player(trade_incoming)
	var incoming_salary := published_salary(incoming)
	var veil := ColorRect.new()
	trade_modal = veil
	veil.name = "TradeModal"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.03, 0.05, 0.78)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 55
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 80, 860), minf(get_viewport_rect().size.y - 80, 500))
	sheet.add_theme_stylebox_override("panel", panel_style(Color("0c1927fc"), ORANGE, 18, 2))
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	sheet.add_child(padded(box, 12))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var title_lab := label("選擇我方球員（可多選）", 20, ORANGE, true)
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	head.add_child(action_button("取消", Color("27394a"), func(): close_trade_modal(), Vector2(88, 40)))
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.scroll_deadzone = 12
	box.add_child(body_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	body_scroll.add_child(body)
	body.add_child(trade_salary_compare_panel(incoming_salary))
	body.add_child(callout("交易費", "另付 $%d 萬（約換入年薪 35%%）。這筆不能代替「合計年薪必須 ≥ 換入年薪」。" % trade_fee_for(incoming), GOLD))
	var compare_scroll := ScrollContainer.new()
	compare_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare_scroll.custom_minimum_size = Vector2(0, 168)
	compare_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(compare_scroll)
	var compare := HBoxContainer.new()
	compare.alignment = BoxContainer.ALIGNMENT_CENTER
	compare.add_theme_constant_override("separation", 12)
	compare_scroll.add_child(compare)
	compare.add_child(lobby_player_card(incoming, false, -1, false, market_card_width()))
	if not trade_out_indices.is_empty():
		compare.add_child(label("← 換 →", 16, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
		for idx in trade_out_indices:
			if idx >= 0 and idx < team_players.size():
				compare.add_child(lobby_player_card(team_players[idx], false, -1, false, market_card_width()))
	var mine := HFlowContainer.new()
	mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine.add_theme_constant_override("h_separation", 8)
	mine.add_theme_constant_override("v_separation", 8)
	body.add_child(mine)
	for i in team_players.size():
		var player: Dictionary = team_players[i]
		if is_veteran_player(player) or is_locked_prize(player):
			continue
		var idx := i
		var picked := trade_out_indices.has(idx)
		var card := lobby_player_card(player, false, -1, false, market_card_width(), func():
			toggle_trade_out(idx)
		, -1, "已選" if picked else "點選加入")
		if picked:
			card.modulate = Color(1.08, 1.04, 0.84)
		mine.add_child(card)
	if mine.get_child_count() == 0:
		body.add_child(label("目前沒有可交易的我方球員。", 13, MUTED))
	if not trade_out_indices.is_empty():
		var live_block := ""
		if trade_outgoing_salary() < incoming_salary:
			live_block = "我方合計年薪仍低於換入年薪，請再選我方球員。"
		else:
			live_block = can_replace_trade_player(incoming, trade_out_indices)
		if not live_block.is_empty():
			body.add_child(callout("目前無法交易", live_block, RED))
	if not error_text.is_empty():
		body.add_child(callout("錯誤", error_text, RED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var confirm := gold_action_button("交易", func():
		complete_trade(incoming)
	, Vector2(0, 48))
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(confirm)

func trade_salary_compare_panel(incoming_salary: int) -> Control:
	var mine := trade_outgoing_salary()
	var have := not trade_out_indices.is_empty()
	var body := "換入年薪 $%d 萬" % incoming_salary
	var accent := ORANGE
	if have:
		var diff := mine - incoming_salary
		body += "　·　我方合計 $%d 萬（%d 人）" % [mine, trade_out_indices.size()]
		if diff >= 0:
			body += "　·　差額 +$%d 萬　·　年薪條件通過" % diff
			accent = GREEN
		else:
			body += "　·　還差 $%d 萬　·　可再加選我方球員" % absi(diff)
			accent = RED
	else:
		body += "　·　我方合計 —　·　可選一張或以上"
	return callout("年薪對照（合計必須 ≥）", body, accent)

func complete_trade(raw: Dictionary) -> void:
	if team_has_player(raw):
		trade_fail("這名球員已經在名單或保管箱裡")
		return
	if is_veteran_player(raw) or is_locked_prize(raw):
		trade_fail("交易市場不提供黃金卡或鑽石卡")
		return
	if trade_out_indices.is_empty():
		trade_fail("請先選至少一名我方球員，再按交易")
		return
	var incoming := to_game_player(raw)
	var incoming_salary := published_salary(incoming)
	var outgoing_salary := trade_outgoing_salary()
	if outgoing_salary < incoming_salary:
		trade_fail("錯誤：我方合計 $%d 萬，低於換入 $%d 萬。可再加選球員。" % [outgoing_salary, incoming_salary])
		return
	incoming["tier"] = "TRADE"
	var block := can_replace_trade_player(incoming, trade_out_indices)
	if not block.is_empty():
		trade_fail(block)
		return
	var cost: int = trade_fee_for(incoming)
	if budget_million < cost:
		trade_fail("交易費不足：需要約 $%d 萬。年薪對照通過也不能用這筆代替。" % cost)
		return
	var server_authorized := server_spend_authorized
	if not auth_access.is_empty() and not server_authorized:
		if not server_spend_inflight:
			request_server_market_fee("trade_fee", str(incoming.get("id", "")), func(ok: bool):
				if ok:
					call_deferred("complete_trade", incoming)
			)
		return
	server_spend_authorized = false
	var gone := "、".join(trade_outgoing_names())
	var keep := 0
	var idxs := trade_out_indices.duplicate()
	idxs.sort()
	keep = int(idxs[0])
	for i in range(idxs.size() - 1, 0, -1):
		team_players.remove_at(int(idxs[i]))
	if not server_authorized:
		budget_million -= cost
	chemistry = clampi(chemistry - 2, 0, 100)
	team_players[keep] = incoming
	apply_combo_label()
	last_event = "交易完成：%s 換入，換走 %s，支付約 $%d 萬。對手本場仍用原陣容，換人只改你的名單。" % [raw.get("name", "球員"), gone, cost]
	last_news = last_event
	trade_notice_pending = true
	push_news(last_event)
	trade_out_indices.clear()
	trade_incoming = {}
	close_trade_modal()
	save_game()
	show_roster()
	show_card_reveal(incoming, func():
		show_purchase_success("交易完成 · %s" % str(incoming.get("name", "球員")), "已支付交易費 $%d 萬" % cost)
	, "對手比賽仍用原陣容")

func trade_fail(message: String) -> void:
	if is_instance_valid(trade_modal):
		show_trade_offer_modal(message)
	else:
		flash_notice(message)

func free_agent_signing_fee(raw: Dictionary) -> int:
	return maxi(45, int(float(published_salary(raw)) * 1.2))

func can_sign_free_agent(raw: Dictionary) -> String:
	if is_veteran_player(raw) or is_locked_prize(raw):
		return "自由市場不提供黃金卡或鑽石卡"
	var block := can_sign_player(raw)
	if not block.is_empty():
		return block
	var cost := free_agent_signing_fee(raw)
	if budget_million < cost:
		return "資金不足：簽約費 $%d 萬，可用 $%d 萬，還差 $%d 萬。薪資帽剩餘空間不是資金。" % [cost, budget_million, cost - budget_million]
	return ""

func sign_free_agent(raw: Dictionary) -> void:
	var incoming := to_game_player(raw)
	var block := can_sign_free_agent(incoming)
	if not block.is_empty():
		flash_notice(block)
		return
	var cost := free_agent_signing_fee(incoming)
	var server_authorized := server_spend_authorized
	if not auth_access.is_empty() and not server_authorized:
		if not server_spend_inflight:
			request_server_market_fee("sign_player", str(incoming.get("id", "")), func(ok: bool):
				if ok:
					call_deferred("sign_free_agent", incoming)
			)
		return
	server_spend_authorized = false
	if not server_authorized:
		budget_million -= cost
	team_players.append(incoming)
	apply_combo_label()
	chemistry = clampi(chemistry - 1, 0, 100)
	last_event = "%s 加盟：資金扣除簽約費 $%d 萬，年薪 $%d 萬計入薪資帽。" % [incoming.get("name", "球員"), cost, published_salary(incoming)]
	last_news = last_event
	save_game()
	show_roster()
	show_card_reveal(incoming, func():
		show_purchase_success("簽下 %s" % str(incoming.get("name", "球員")), "簽約費 $%d 萬" % cost)
	)

func draft_player(raw: Dictionary) -> void:
	if not draft_eligible() or bool(draft_state.get("completed", false)):
		flash_notice("尚未取得選秀資格，或本季已完成選秀")
		return
	prepare_draft()
	var rookie: Dictionary = {}
	for candidate in remaining_draft_players():
		if str(candidate.id) == str(raw.get("id", "")):
			rookie = candidate.duplicate(true)
			break
	if rookie.is_empty():
		flash_notice("這名球員已被選走，請重新查看名單")
		return
	draft_state["completed"] = true
	draft_state["selection"] = str(rookie.name)
	drafted_prospect_ids.append(str(rookie.id))
	draft_state["picks"].append({"team":club_name, "player":rookie.name})
	var destination := "加入名單"
	var duplicate := team_has_player(rookie)
	if can_sign_player(rookie).is_empty() and not duplicate:
		team_players.append(rookie)
		apply_combo_label()
	else:
		card_inventory.append(rookie)
		destination = "重複卡放入保管箱" if duplicate else "放入保管箱"
	if duplicate:
		duplicate_notices.append("%s → 重複卡已加入保管箱" % rookie.get("name", "球員"))
		call_deferred("show_duplicate_notice")
	for i in range(int(draft_state.get("user_pick", 1)), draft_state.order.size()):
		draft_ai_pick(draft_state.order[i])
	last_event = "選秀新人 %s：%s。" % [rookie.name, destination]
	last_news = last_event
	save_game()
	show_draft_market()
	flash_notice(last_event)

func show_gacha_market() -> void:
	ensure_season_scout()
	active_menu = "collection"
	var content := begin_screen("球探", "點隨機卡片購買・只扣球探點・不含鑽石卡", 4)
	var scout_info_row := HBoxContainer.new()
	scout_info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scout_info_row.add_theme_constant_override("separation", 8)
	if not is_handheld():
		content.add_child(scout_info_row)
	var combo_box := combo_status_banner(true)
	combo_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scout_info_row.add_child(combo_box)
	var odds := wrap_label(scout_probability_text() + "・不含鑽石卡", 11, MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT)
	odds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scout_info_row.add_child(odds)
	if gacha_candidates.is_empty():
		if generate_scout_candidates():
			save_game() # Reopening/restarting keeps the same initial offers.
	if gacha_candidates.is_empty():
		content.add_child(callout("卡池暫不可用", "卡池資料不完整，尚未扣除任何資源。", RED))
	var probabilities := fit_label("出現機率｜" + scout_probability_text(true), 18, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	probabilities.name = "ScoutProbabilities"
	content.add_child(probabilities)
	var board: Container = VBoxContainer.new() if is_handheld() else ScrollContainer.new()
	board.name = "ScoutBoard"
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if board is VBoxContainer:
		# The offer row belongs in the visual middle of the available court. Keeping
		# it at the top left a large dead zone below the purchase buttons on phones.
		board.custom_minimum_size.y = maxf(150.0, content_view_h() * 0.78)
		board.alignment = BoxContainer.ALIGNMENT_CENTER
	if board is ScrollContainer:
		board.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		board.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		board.custom_minimum_size = Vector2(0, maxi(150, int(content_view_h() * 0.58)))
	content.add_child(board)
	var grid := GridContainer.new()
	grid.name = "ScoutOfferGrid"
	if is_handheld():
		# Never force six cards into a narrow portrait or split-screen viewport.
		# The grid remains touch friendly and grows back to six columns on wide
		# landscape phones/tablets.
		grid.columns = clampi(int(usable_view().x / 96.0), 3, 6)
	else:
		grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	board.add_child(grid)
	if board is ScrollContainer:
		bind_scroll_child_width(board, grid)
	var scout_cols := maxi(1, grid.columns)
	var scout_card_w := clampi(int((usable_view().x - UI_SCOUT_GRID_GUTTER - 8.0 * float(scout_cols - 1)) / float(scout_cols)), 96, 114) if is_handheld() else market_card_width()
	for i in gacha_candidates.size():
		var card := gacha_card(gacha_candidates[i], i, scout_card_w)
		var card_slot := CenterContainer.new()
		card_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_slot.add_child(card)
		grid.add_child(card_slot)
	if is_handheld():
		scout_info_row.free()
	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	if is_handheld():
		pin_above_dock(content, actions)
	else:
		content.add_child(actions)
	if is_handheld():
		actions.add_child(action_button("球探規則", Color("254e6b"), func(): show_guide_sheet("球探規則", scout_rules_text())))
	var refresh := action_button("更換下一批 · %d 黃金" % SCOUT_REFRESH_GOLD, GOLD, func(): refresh_scout_board(), Vector2(0, 44))
	refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(refresh)

func inventory_has_player(raw: Dictionary) -> bool:
	var key := player_identity_key(raw)
	if key.is_empty():
		return false
	for item in card_inventory:
		if item is Dictionary and player_identity_key(item) == key:
			return true
	return false

func inventory_index_of(player: Dictionary) -> int:
	var key := player_identity_key(player)
	if key.is_empty():
		return -1
	for i in card_inventory.size():
		var item = card_inventory[i]
		if item is Dictionary and player_identity_key(item) == key:
			return i
	return -1

func stash_to_vault(player: Dictionary) -> bool:
	if player.is_empty():
		return false
	if card_inventory.size() >= vault_capacity():
		flash_notice("保管箱已滿（%d／%d），可到商店增加 10 格" % [card_inventory.size(), vault_capacity()])
		return false
	card_inventory.append(player.duplicate(true))
	return true

func duplicate_card_count(player: Dictionary) -> int:
	var key := player_identity_key(player)
	if key.is_empty():
		return 0
	var count := 0
	for item in team_players:
		if item is Dictionary and player_identity_key(item) == key:
			count += 1
	for item in card_inventory:
		if item is Dictionary and player_identity_key(item) == key:
			count += 1
	return count

func can_release_duplicate(player: Dictionary) -> bool:
	return not player.is_empty() and not is_locked_prize(player) and duplicate_card_count(player) > 1

func release_vault_player(index: int, confirmed := false) -> void:
	if index < 0 or index >= card_inventory.size() or not (card_inventory[index] is Dictionary):
		return
	var card: Dictionary = card_inventory[index]
	if not can_release_duplicate(card):
		flash_notice("只有重複卡可以釋出換黃金；鑽石卡不可釋出。")
		return
	var reward := duplicate_gold_for(card)
	if not confirmed:
		show_guide_sheet("釋出重複卡", "%s 已有重複卡，釋出這張可獲得 %d 黃金。" % [card.get("name", "球員"), reward], GOLD, "確認釋出", func():
			close_guide_modal()
			if index < card_inventory.size() and can_release_duplicate(card_inventory[index]) and player_identity_key(card_inventory[index]) == player_identity_key(card):
				release_vault_player(index, true)
		)
		return
	card_inventory.remove_at(index)
	gold += reward
	last_event = "%s 重複卡已釋出，獲得黃金 +%d。" % [card.get("name", "球員"), reward]
	last_news = last_event
	save_game()
	flash_notice(last_event)
	show_card_vault()

func vault_sort_label() -> String:
	match vault_sort_mode:
		"ovr_asc": return "OVR 低→高"
		"salary_desc": return "年薪 高→低"
		"name": return "姓名 A→Z"
		"tier": return "卡色 稀有→普"
		_: return "OVR 高→低"

func cycle_vault_sort() -> void:
	var modes := ["ovr_desc", "ovr_asc", "salary_desc", "name", "tier"]
	var at := modes.find(vault_sort_mode)
	vault_sort_mode = modes[(at + 1) % modes.size()]
	show_card_vault()

func sorted_vault_indices() -> Array[int]:
	var indices: Array[int] = []
	for i in card_inventory.size():
		if card_inventory[i] is Dictionary and vault_matches_filter(to_game_player(card_inventory[i])):
			indices.append(i)
	indices.sort_custom(func(a: int, b: int):
			var left: Dictionary = to_game_player(card_inventory[a])
			var right: Dictionary = to_game_player(card_inventory[b])
			match vault_sort_mode:
				"ovr_asc":
					if int(left.get("ovr", 70)) != int(right.get("ovr", 70)):
						return int(left.get("ovr", 70)) < int(right.get("ovr", 70))
				"salary_desc":
					if int(left.get("salary_million", 0)) != int(right.get("salary_million", 0)):
						return int(left.get("salary_million", 0)) > int(right.get("salary_million", 0))
				"name":
					if str(left.get("name", "")) != str(right.get("name", "")):
						return str(left.get("name", "")) < str(right.get("name", ""))
				"tier":
					var rank := {"diamond": 0, "gold": 1, "purple": 2, "red": 3, "blue": 4, "green": 5, "cyan": 6}
					if int(rank.get(player_tier_key(left), 9)) != int(rank.get(player_tier_key(right), 9)):
						return int(rank.get(player_tier_key(left), 9)) < int(rank.get(player_tier_key(right), 9))
				_:
					if int(left.get("ovr", 70)) != int(right.get("ovr", 70)):
						return int(left.get("ovr", 70)) > int(right.get("ovr", 70))
			return a < b
	)
	return indices

func move_roster_to_vault(index: int) -> void:
	if index < 0 or index >= team_players.size() or team_players.size() <= minimum_roster_to_play():
		flash_notice("至少保留 7 人才能開打")
		return
	var card: Dictionary = team_players[index]
	if not stash_to_vault(card):
		return
	team_players.remove_at(index)
	selected_foundation = clampi(selected_foundation, 0, maxi(0, team_players.size() - 1))
	apply_combo_label()
	last_event = "%s 已放入保管箱。" % card.get("name", "球員")
	save_game()
	show_roster()

func place_from_vault(index: int) -> void:
	if index < 0 or index >= card_inventory.size():
		return
	var raw: Dictionary = card_inventory[index]
	if roster_has_player(raw):
		flash_notice("這名球員已經在名單裡，保管箱這張不能再登")
		show_card_vault()
		return
	var block := can_sign_player(raw, true)
	if block.is_empty():
		place_inventory_card(index)
		return
	if team_players.size() < minimum_roster_to_play():
		flash_notice(block)
		show_card_vault()
		return
	flash_notice(block)
	show_vault_swap_picker(index)

func vault_login_tag(raw: Dictionary) -> String:
	if roster_has_player(raw):
		return "已在名單"
	var block := can_sign_player(raw, true)
	if block.is_empty():
		return "點選登錄"
	if "12" in block:
		return "滿12 · 點卡換人"
	if "薪資" in block:
		return "超帽 · 點卡換人"
	if "外援" in block:
		return "外援滿 · 點卡換人"
	if "外籍生" in block:
		return "外籍生滿 · 點卡換人"
	if "老將" in block:
		return "已有老將 · 點卡換人"
	return "點卡換人"

func can_vault_swap_with(incoming: Dictionary, out_index: int) -> String:
	if player_in_other_team(incoming):
		return "這名球員已登錄另一支隊伍，請先從原隊移到保管箱"
	if out_index < 0 or out_index >= team_players.size():
		return "請選名單上要換下的人"
	var outgoing: Dictionary = team_players[out_index]
	if player_identity_key(incoming) == player_identity_key(outgoing):
		return "同一人不用換"
	if roster_has_player(incoming):
		return "這名球員已經在名單裡"
	var base_salary := roster_salary() - published_salary(outgoing)
	var veterans := 0
	var foreigners := 0
	var students := 0
	for i in team_players.size():
		if i == out_index:
			continue
		var player: Dictionary = team_players[i]
		if is_veteran_player(player):
			veterans += 1
		if is_foreigner(player):
			foreigners += 1
		if is_foreign_student(player):
			students += 1
	if is_veteran_player(incoming) and veterans >= 1:
		return "一隊只能有一名黃金世代老將，請先換下現有老將"
	if is_foreigner(incoming) and foreigners >= foreigner_limit():
		return "外援已滿，請換下一名外援"
	if is_foreign_student(incoming) and students >= foreign_student_limit():
		return "外籍生已滿，請換下一名外籍生"
	if base_salary + published_salary(incoming) > salary_cap:
		return "換入後仍超薪資帽，請換下年薪更高的人"
	return ""

func show_vault_swap_picker(vault_index: int) -> void:
	if vault_index < 0 or vault_index >= card_inventory.size():
		show_card_vault()
		return
	var incoming: Dictionary = to_game_player(card_inventory[vault_index])
	active_menu = "vault"
	var content := begin_screen("換人登錄", "%s 進名單，選一名換下進保管箱。" % str(incoming.get("name", "球員")), 4)
	content.add_child(callout("為什麼不能直接登", can_sign_player(incoming, true), ORANGE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	row.add_child(lobby_player_card(incoming, false, -1, false, market_card_width()))
	var board := ScrollContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(board)
	var mine := HFlowContainer.new()
	mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine.add_theme_constant_override("h_separation", 8)
	mine.add_theme_constant_override("v_separation", 8)
	board.add_child(mine)
	for i in team_players.size():
		var player: Dictionary = team_players[i]
		var idx := i
		var why := can_vault_swap_with(incoming, idx)
		var card := lobby_player_card(player, false, -1, false, market_card_width(), func():
			if not why.is_empty():
				flash_notice(why)
				return
			apply_vault_swap(vault_index, idx)
		)
		if not why.is_empty():
			card.modulate = Color(0.72, 0.74, 0.78)
			card.tooltip_text = why
		else:
			card.tooltip_text = "點他換下"
		mine.add_child(card)
	content.add_child(action_button("回保管箱", Color("254e6b"), func(): show_card_vault(), Vector2(0, 44)))

func apply_vault_swap(vault_index: int, out_index: int) -> void:
	if vault_index < 0 or vault_index >= card_inventory.size() or out_index < 0 or out_index >= team_players.size():
		flash_notice("請重新選擇")
		show_card_vault()
		return
	var incoming: Dictionary = to_game_player(card_inventory[vault_index])
	var why := can_vault_swap_with(incoming, out_index)
	if not why.is_empty():
		flash_notice(why)
		show_vault_swap_picker(vault_index)
		return
	var outgoing: Dictionary = team_players[out_index]
	card_inventory.remove_at(vault_index)
	team_players[out_index] = incoming
	stash_to_vault(outgoing)
	apply_combo_label()
	last_event = "%s 登錄，%s 放回保管箱。" % [incoming.get("name", "球員"), outgoing.get("name", "球員")]
	save_game()
	flash_notice(last_event)
	show_roster()

func player_identity_key(raw: Dictionary) -> String:
	return str(raw.get("name", "")).strip_edges()

func roster_has_player(raw: Dictionary) -> bool:
	var key := player_identity_key(raw)
	if key.is_empty():
		return false
	for player in team_players:
		if player_identity_key(player) == key:
			return true
	return false

func team_has_player(raw: Dictionary) -> bool:
	return roster_has_player(raw) or inventory_has_player(raw) or player_in_other_team(raw)

func player_in_other_team(raw: Dictionary) -> bool:
	var key := player_identity_key(raw)
	if key.is_empty() or team_profiles.is_empty():
		return false
	for i in team_profiles.size():
		if i == active_team_index or not (team_profiles[i] is Dictionary):
			continue
		var players = team_profiles[i].get("players", [])
		if not (players is Array):
			continue
		for item in players:
			if item is Dictionary and player_identity_key(item) == key:
				return true
	return false

func cycle_team_profile() -> void:
	if not second_team_unlocked:
		select_store_product("便利功能", "second_team")
		flash_notice("請先解鎖第二隊伍")
		return
	if match_rewards_pending or current_stage == 6:
		flash_notice("請先完成目前比賽，再切換主隊")
		return
	save_extra_run()
	var current := collect_save_data()
	var before_teams := slot_save_path(active_save_slot) + ".before_team_careers_v1"
	if not FileAccess.file_exists(before_teams) and SaveStore.write_save(before_teams, current) != OK:
		flash_notice("隊伍切換前備份失敗，未切換；請確認裝置空間")
		return
	var next := (active_team_index + 1) % AVAILABLE_TEAM_PROFILES
	if team_profiles[next].is_empty():
		team_profiles[next] = {"name": "第二隊" if next == 1 else "第三隊", "logo_id": "club_01", "players": []}
	var profile: Dictionary = team_profiles[next]
	var switched := TeamCareer.for_profile(current, profile, next)
	# Commit the complete switch before changing the active UI. A disk failure
	# leaves the current team playable and never half-switches its resources.
	if SaveStore.write_save(slot_save_path(active_save_slot), switched) != OK:
		flash_notice("切換存檔失敗，保留目前隊伍；請確認裝置空間")
		return
	load_game(false)
	save_game()
	show_dashboard()

func compact_unique_owned() -> int:
	# Duplicate cards are collectible now. Keep every card instance in the
	# vault; roster eligibility still prevents two copies in one lineup.
	return 0

func duplicate_gold_for(player: Dictionary) -> int:
	match player_tier_key(player):
		"diamond":
			return 120
		"gold":
			return 100
		"purple":
			return 70
		"red":
			return 40
		"blue":
			return 25
		"green":
			return 15
		_:
			return 10

func apply_duplicate_convert(player: Dictionary) -> int:
	var gain := duplicate_gold_for(player)
	gold += gain
	duplicate_notices.append("%s → %d 黃金" % [player.get("name", "球員"), gain])
	call_deferred("show_duplicate_notice")
	return gain

func show_duplicate_notice() -> void:
	if duplicate_notices.is_empty():
		return
	var lines := "\n".join(duplicate_notices)
	duplicate_notices.clear()
	show_guide_sheet("重複卡已收錄", lines + "\n同名卡片現在允許重複取得，會完整保留在保管箱；同一隊仍不能同時登錄兩張相同球員。", GOLD)
	guide_modal.name = "DuplicateCardNotice"

func scout_player_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var seen := {}
	var sources: Array = all_league_players()
	sources.append_array(public_players)
	# Include all collected veteran profiles so gold never depends on a short public-stat list.
	sources.append_array(career_rules.get("golden_generation", []))
	for raw in sources:
		if not (raw is Dictionary) or is_locked_prize(raw):
			continue
		var card := to_game_player(raw)
		var key := player_identity_key(card)
		if key.is_empty() or seen.has(key) or player_tier_key(card) == "diamond":
			continue
		seen[key] = true
		pool.append(card)
	return pool

func scout_rarity_buckets(pool: Array[Dictionary]) -> Dictionary:
	var buckets := {}
	for spec in SCOUT_RARITY_PROBABILITIES:
		buckets[spec.id] = []
	for card in pool:
		if is_locked_prize(card):
			continue
		var rarity := player_tier_key(card)
		if buckets.has(rarity):
			buckets[rarity].append(card)
	return buckets

func generate_scout_candidates() -> bool:
	var buckets := scout_rarity_buckets(scout_player_pool())
	for spec in SCOUT_RARITY_PROBABILITIES:
		if buckets[spec.id].is_empty():
			# Never silently reroll another color or charge for an incomplete catalog.
			return false
	gacha_candidates.clear()
	scout_board_serial += 1
	fill_scout_board_from_buckets(buckets)
	return true

func fill_scout_board_from(pool: Array[Dictionary]) -> void:
	var buckets := scout_rarity_buckets(pool)
	for spec in SCOUT_RARITY_PROBABILITIES:
		if buckets[spec.id].is_empty():
			return
	fill_scout_board_from_buckets(buckets)

func fill_scout_board_from_buckets(buckets: Dictionary) -> void:
	while gacha_candidates.size() < 6:
		var rarity := scout_roll_rarity_id()
		var candidates: Array = buckets[rarity]
		var fresh: Array = candidates.filter(func(card: Dictionary): return not scout_board_has_player(card))
		# Prefer different players within the drawn color, without changing its probability.
		if not fresh.is_empty():
			candidates = fresh
		var chosen: Dictionary = candidates[randi_range(0, candidates.size() - 1)].duplicate(true)
		chosen["scout_offer_id"] = "%d:%d" % [scout_board_serial, gacha_candidates.size()]
		gacha_candidates.append(chosen)

func scout_rarity_for_roll(roll: int) -> String:
	assert(roll >= 1 and roll <= 100)
	var total := 0
	for item in SCOUT_RARITY_PROBABILITIES:
		total += int(item.percent)
		if roll <= total:
			return str(item.id)
	return "cyan"

func scout_roll_rarity_id() -> String:
	return scout_rarity_for_roll(randi_range(1, 100))

func scout_board_has_player(raw: Dictionary) -> bool:
	var key := player_identity_key(raw)
	if key.is_empty():
		return false
	for have in gacha_candidates:
		if player_identity_key(have) == key:
			return true
	return false

func refresh_scout_board() -> void:
	var today := taiwan_today_key()
	var free_today := scout_free_refresh_date != today
	if not free_today and gold < SCOUT_REFRESH_GOLD:
		flash_notice("今日免費刷新已使用；更換下一批需要 %d 黃金。購買球員才使用球探點。" % SCOUT_REFRESH_GOLD)
		return
	if not generate_scout_candidates():
		flash_notice("卡池資料不完整，未更換卡片、未扣球探點")
		return
	var server_authorized := server_spend_authorized
	if not free_today and not auth_access.is_empty() and not server_authorized:
		if not server_spend_inflight:
			request_server_economy_spend("scout_refresh", 0, -SCOUT_REFRESH_GOLD, 0, 0, func(ok: bool):
				if ok:
					call_deferred("refresh_scout_board")
			)
		return
	server_spend_authorized = false
	if free_today:
		scout_free_refresh_date = today
		last_progress_event = "球探桌今日免費刷新完成。"
	elif not server_authorized:
		gold -= SCOUT_REFRESH_GOLD
		last_progress_event = "球探桌已換一批，花費 %d 黃金。" % SCOUT_REFRESH_GOLD
	save_game()
	show_gacha_market()

func scout_rarity(player: Dictionary) -> Dictionary:
	var key := player_tier_key(player)
	for item in SCOUT_RARITY_PROBABILITIES:
		if item.id == key:
			var result: Dictionary = item.duplicate()
			result["color"] = tier_color(key)
			return result
	return {"id": key, "name": "不在球探卡池", "color": MUTED, "percent": 0}

func scout_rules_text() -> String:
	return "點卡片查看資料，再按卡片下方的購買鍵；買球員只扣球探點。\nOVR 80 以上球員只會出現在球探卡池，不會出現在自由市場或交易。\n每張新上架卡片的出現機率：%s；合計 100%%，不含鑽石卡。\n每天第一次更換下一批免費，之後每批花費 20 黃金；刷新不扣球探點。" % scout_probability_text()

func scout_probability_text(compact := false) -> String:
	var parts := PackedStringArray()
	for item in SCOUT_RARITY_PROBABILITIES:
		var caption := str(item.name).left(1) if compact else str(item.name)
		parts.append("%s %d%%" % [caption, int(item.percent)])
	return " · ".join(parts)

func gacha_card(raw: Dictionary, index: int, card_w := 94, _card_h := -1) -> Control:
	var cost := scout_point_cost(raw)
	var shown_w := maxi(40, roundi(float(card_w) * 0.75))
	var captured: Dictionary = raw
	var idx := index
	var offer_id := str(raw.get("scout_offer_id", ""))
	var box := VBoxContainer.new()
	box.name = "ScoutOffer"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.add_child(lobby_player_card(raw, false, -1, false, card_w, func():
		show_player_sheet(captured, func(): show_gacha_market())
	))
	var buy := action_button("購買 %d 球探點" % cost, CYAN, func():
		claim_scout_choice(idx, player_identity_key(captured), offer_id)
	, Vector2(maxi(96, shown_w), 32))
	buy.name = "ScoutBuyButton"
	buy.add_theme_font_size_override("font_size", 12 if is_handheld() else 11)
	box.add_child(buy)
	return box

func claim_scout_choice(index: int, expected_player := "", expected_offer := "") -> void:
	if index < 0 or index >= gacha_candidates.size():
		return
	var preview: Dictionary = gacha_candidates[index]
	if not expected_player.is_empty() and player_identity_key(preview) != expected_player:
		return
	if is_locked_prize(preview) or player_tier_key(preview) == "diamond":
		flash_notice("鑽石卡不在球探販售範圍，未扣球探點")
		return
	if not expected_offer.is_empty() and str(preview.get("scout_offer_id", "")) != expected_offer:
		return
	var cost := scout_point_cost(preview)
	if scout_points < cost:
		flash_notice("球探點不足：%s 年薪 $%d 萬要 %d 點，現在只有 %d。贏球會再補。" % [str(preview.get("name", "球員")), published_salary(preview), cost, scout_points])
		return
	var preview_goes_to_vault := team_has_player(preview) or not can_sign_player(preview).is_empty()
	if preview_goes_to_vault and card_inventory.size() >= vault_capacity():
		flash_notice("保管箱已滿（%d／%d），未扣球探點" % [card_inventory.size(), vault_capacity()])
		return
	var server_authorized := server_spend_authorized
	if not auth_access.is_empty() and not server_authorized:
		if not server_spend_inflight:
			request_server_scout_purchase(str(preview.get("id", "")), func(ok: bool):
				if ok:
					call_deferred("claim_scout_choice", index, expected_player, expected_offer)
			)
		return
	server_spend_authorized = false
	var chosen: Dictionary = preview.duplicate(true)
	if not server_authorized:
		scout_points -= cost
	gacha_candidates.remove_at(index)
	var duplicate := team_has_player(chosen)
	if duplicate:
		chosen["duplicate_pull"] = true
		stash_to_vault(chosen)
		duplicate_notices.append("%s → 重複卡已加入保管箱" % chosen.get("name", "球員"))
		call_deferred("show_duplicate_notice")
		last_event = "重複卡：%s 已加入保管箱，可留作收藏或日後替換。" % chosen.get("name", "球員")
		last_news = last_event
		save_game()
		show_gacha_market()
		queue_purchase_success(str(chosen.get("name", "球員")), "%d 球探點 · 重複卡已放入保管箱" % cost)
		return
	var block := can_sign_player(chosen)
	if block.is_empty():
		team_players.append(chosen)
		apply_combo_label()
		last_event = "球探挖掘：%s（OVR %d · %d 球探點）。" % [chosen.get("name", "球員"), int(chosen.get("ovr", 70)), cost]
		last_news = last_event
		save_game()
		show_roster()
		show_card_reveal(chosen, func():
			show_purchase_success(str(chosen.get("name", "球員")), "已使用 %d 球探點並加入名單" % cost)
		)
		return
	stash_to_vault(chosen)
	last_event = "球探挖掘：%s 已放入保管箱（OVR %d · %d 球探點）。" % [chosen.get("name", "球員"), int(chosen.get("ovr", 70)), cost]
	last_news = last_event
	save_game()
	show_card_vault()
	show_card_reveal(chosen, func():
		show_purchase_success(str(chosen.get("name", "球員")), "已使用 %d 球探點並放入保管箱" % cost)
	)

func supporter_accent() -> Color:
	match supporter_theme:
		"賽博龐克主場": return Color("d94cff")
		"冠軍金色主場": return GOLD
		"夜場靛藍": return Color("9465d9")
		"場邊金": return GOLD
		_: return TAIWAN_CYAN

func show_supporter_club() -> void:
	active_menu = "market"
	var content := begin_screen("支持者展示", "球館、卡框、球探報告與徽章 · 純外觀，不影響勝負", 4)
	content.add_child(callout("公平支持原則", "外觀不會改勝負。球館配色只是個人展示。", Color("a879e6")))
	var themes := HFlowContainer.new()
	themes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	themes.custom_minimum_size = Vector2(0, 110)
	themes.alignment = FlowContainer.ALIGNMENT_CENTER
	themes.add_theme_constant_override("h_separation", 10)
	content.add_child(themes)
	var theme_entries: Array[Dictionary] = [{"id":"standard", "theme":"標準球館", "title":"標準球館"}]
	for product in store_products():
		if product.has("theme"):
			theme_entries.append(product)
	for entry in theme_entries:
		var theme_name := str(entry.get("theme", "標準球館"))
		var product_id := str(entry.get("id", "standard"))
		var owned := product_id == "standard" or store_cosmetics_owned.has(product_id)
		var status := "目前使用中" if supporter_theme == theme_name else ("點擊套用" if owned else "尚未解鎖 · 前往商店")
		themes.add_child(market_entry_card(str(entry.get("title", theme_name)), "%s · 純外觀，不影響 OVR 或勝率" % status, GOLD if owned else Color("607084"), func(): set_supporter_theme(theme_name)))
	content.add_child(callout("目前展示", "%s · 配色只改外觀" % supporter_theme, supporter_accent()))

func supporter_theme_product_id(theme_name: String) -> String:
	if theme_name == "標準球館":
		return "standard"
	for product in store_products():
		if str(product.get("theme", "")) == theme_name:
			return str(product.id)
	return ""

func set_supporter_theme(theme_name: String) -> void:
	var product_id := supporter_theme_product_id(theme_name)
	if product_id.is_empty():
		flash_notice("找不到這個球場主題")
		return
	if product_id != "standard" and not store_cosmetics_owned.has(product_id):
		select_store_product("球場", product_id)
		flash_notice("請先在商店解鎖這座球場")
		return
	supporter_theme = theme_name
	home_environment_mode = "arena"
	last_progress_event = "支持者外觀已切換為「%s」；這是純視覺設定，沒有任何戰力加成。" % supporter_theme
	save_game()
	show_supporter_club()

func challenge_label(challenge_id: String) -> String:
	match challenge_id:
		"small_market": return "小市場重建"
		"salary_cap": return "薪資帽危機"
		"national_pride": return "中華隊出征"
		_: return "自由挑戰"

func challenge_story(challenge_id: String) -> String:
	match challenge_id:
		"small_market":
			return "地方球館快撐不下去，只能用低薪球員和臨場判斷把球隊救回來。"
		"salary_cap":
			return "主力合約同時到期，薪資空間只剩一點；每一筆簽約都可能讓球隊失控。"
		"national_pride":
			return "國家隊臨時徵召，你要從自己的卡片保管箱湊出能代表台灣的陣容。"
		_:
			return "每一場選擇都會改變球隊下一步。"

func challenge_description(challenge_id: String) -> String:
	match challenge_id:
		"small_market": return "用平均 OVR 77 以下的陣容贏 2 場。破關：資金 +$120 萬、球探點 +4。"
		"salary_cap": return "在賽前薪資不高於 $650 萬時贏 1 場。破關：資金 +$180 萬、球探點 +3。"
		"national_pride": return "登錄中華隊名單並贏 1 場國際賽。破關：資金 +$250 萬、球探點 +4。"
		_: return "選擇一項長期挑戰，讓每一季都有不同的決策限制。"

func challenge_incident(challenge_id: String) -> String:
	match challenge_id:
		"small_market":
			return ["地方贊助商臨時加碼，替補球員獲得一次證明自己的機會。", "主場停電延誤比賽，替補球員靠穩定發揮接續比賽。"][randi() % 2]
		"salary_cap":
			return ["經紀人突然要求加薪，放棄交易才能守住薪資空間。", "主力受傷缺陣，低薪替補被迫先發。"][randi() % 2]
		"national_pride":
			return ["國家隊臨時少一名球員，保管箱裡的卡成為最後救兵。", "客場球迷製造壓力，球隊必須先穩住防守。"][randi() % 2]
		_:
			return "賽前出現突發狀況，臨場決定將影響下一場。"

func maybe_trigger_challenge_incident() -> void:
	if active_challenge.is_empty() or randf() > 0.35:
		return
	last_progress_event = "突發事件｜%s" % challenge_incident(active_challenge)

func challenge_target(challenge_id: String) -> int:
	return 2 if challenge_id == "small_market" else 1

func challenge_progress_text(challenge_id: String) -> String:
	var progress := int(challenge_progress.get(challenge_id, 0))
	var target := challenge_target(challenge_id)
	var state := "已完成" if bool(challenge_completed.get(challenge_id, false)) else "%d / %d" % [progress, target]
	return "%s · %s" % [challenge_label(challenge_id), state]

func mission_shortcut_title() -> String:
	return "任務！" if mission_alert or daily_checkin_date != taiwan_today_key() else "任務"

func taiwan_today_key() -> String:
	return taiwan_date_key(int(Time.get_unix_time_from_system()))

func taiwan_date_key(utc_seconds: int) -> String:
	var now := Time.get_datetime_dict_from_unix_time(utc_seconds + 8 * 60 * 60)
	return "%04d-%02d-%02d" % [int(now.get("year", 0)), int(now.get("month", 0)), int(now.get("day", 0))]

func monthly_pass_claimable_days(today: String) -> int:
	if not monthly_pass_active or monthly_pass_claimed_days >= 30:
		return 0
	# If the free check-in was already claimed before the pass was purchased,
	# today's reward is considered used and cannot be claimed a second time.
	if daily_checkin_date == today and monthly_pass_claimed_date != today:
		return 0
	if monthly_pass_claimed_date.is_empty():
		return 1
	var from_ts := Time.get_unix_time_from_datetime_string(monthly_pass_claimed_date + "T00:00:00")
	var to_ts := Time.get_unix_time_from_datetime_string(today + "T00:00:00")
	if from_ts < 0 or to_ts < 0:
		return 1
	return clampi(int((to_ts - from_ts) / 86400.0), 0, 30 - monthly_pass_claimed_days)

func show_activity_hub() -> void:
	track_event("screen_activity")
	active_menu = "activity"
	cloud_pull_activity()
	var content := begin_screen("活動", "台灣籃球活動中心 · 賽季期間開放", 4)
	if not auth_access.is_empty():
		content.add_child(cloud_status_panel())
	var hero_tex := load_png_tex("res://assets/art/activity/activity_vs_hero.png")
	if hero_tex != null:
		var hero := TextureRect.new()
		hero.custom_minimum_size = Vector2(0, 128 if is_handheld() else 190)
		hero.texture = hero_tex
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero.modulate.a = 0.0
		content.add_child(hero)
		var hero_tween := hero.create_tween()
		hero_tween.tween_property(hero, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	content.add_child(filters)
	for caption in ["全部", "TPBL", "PLG", "SBL", "國際賽"]:
		var league_filter: String = caption
		var selected := activity_league_filter == league_filter
		filters.add_child(action_button(league_filter, TAIWAN_BLUE if selected else Color("254e6b"), func():
			activity_league_filter = league_filter
			show_activity_hub()
		, Vector2(0, 40)))
	content.add_child(callout("Pick'em 勝負預測", "目前沒有可預測賽事；官方賽程資料更新後會顯示在這裡。", GOLD))
	var schedule_panel := activity_schedule_panel()
	schedule_panel.name = "ActivitySchedule"
	content.add_child(schedule_panel)
	content.add_child(callout("多人積分賽 · 場次不限", "真人先發快照配對，離線也可對戰。LP 升降、賽季排行榜與前三名中華隊資格，由伺服器結算；2026/12/1 台灣時間截止。", ORANGE))
	content.add_child(action_button("進入多人賽季", ORANGE, func(): show_async_season(), Vector2(0, 44)))
	var leaderboard_panel := activity_leaderboard_panel()
	leaderboard_panel.name = "ActivityLeaderboard"
	content.add_child(leaderboard_panel)

func refresh_activity_cloud_panel(kind: String) -> void:
	var panel_name := "ActivitySchedule" if kind == "pull_activity_schedule" else "ActivityLeaderboard"
	var old := find_child(panel_name, true, false)
	if not is_instance_valid(old):
		return
	var parent := old.get_parent()
	var index := old.get_index()
	parent.remove_child(old)
	old.queue_free()
	var updated := activity_schedule_panel() if kind == "pull_activity_schedule" else activity_leaderboard_panel()
	updated.name = panel_name
	parent.add_child(updated)
	parent.move_child(updated, index)

func activity_leaderboard_panel() -> Control:
	var text := "目前尚無排行資料；完成有效預測後會在這裡顯示。"
	if not activity_cloud_leaderboard.is_empty():
		var rows := PackedStringArray()
		for i in mini(5, activity_cloud_leaderboard.size()):
			var item := activity_cloud_leaderboard[i]
			rows.append("%d. %s　%d 分　命中 %d" % [i + 1, str(item.get("display_name", "球迷")), int(item.get("prediction_points", 0)), int(item.get("correct_predictions", 0))])
		text = "\n".join(rows)
	if not prediction_badges.is_empty():
		text += "\n\n我的徽章：" + "、".join(prediction_badges)
	return callout("預測排行榜", text, GOLD)

func activity_schedule_panel() -> Control:
	var schedule: Array[Dictionary] = []
	for item in activity_cloud_schedule:
		var league := str(item.get("league", item.get("competition", ""))).to_upper()
		if activity_league_filter == "全部" or league == activity_league_filter.to_upper():
			schedule.append(item)
	if schedule.is_empty():
		var filter_note := "全部聯盟" if activity_league_filter == "全部" else activity_league_filter
		return callout("雲端賽程 · %s" % filter_note, "目前沒有符合篩選的正式賽程；賽程公布後會在這裡顯示。" if not activity_cloud_schedule.is_empty() else "正式賽程尚未公布，預測功能會在賽程確認後開放。", MUTED)
	var rows := PackedStringArray()
	for i in mini(8, schedule.size()):
		var item := schedule[i]
		var start := str(item.get("starts_at", "時間待補")).replace("T", " ").replace("+00:00", " UTC")
		rows.append("%s　%s vs %s" % [start, str(item.get("home_name", "主隊")), str(item.get("away_name", "客隊"))])
	return callout("雲端賽程 · %s（前 8 場）" % activity_league_filter, "\n".join(rows), CYAN)

func async_rank_label(lp: int) -> String:
	return RankedRules.rank_label(lp)

func async_season_end_key() -> String:
	return "2026-12-01"

func async_season_ended() -> bool:
	return taiwan_today_key() >= async_season_end_key()

func show_async_season(refresh := true) -> void:
	RankedFlow.show_screen(self,refresh)

func play_async_match() -> void:
	RankedFlow.request(self,"play")

func quick_ranked_practice() -> void:
	# A local, non-ranked scrimmage keeps the multiplayer screen useful while
	# the server is waiting for a snapshot opponent. No save, LP or resources
	# are touched; it is purely a fast way to learn the matchup flow.
	if team_players.size() < 5:
		flash_notice("先編好五位先發，才能開始練習賽")
		return
	var opponent: Dictionary = current_match_opponent().duplicate(true)
	if opponent.is_empty():
		opponent = {"name":"系統練習對手", "rating": maxi(65, roundi(average_ovr()) - 2), "team_id":"practice"}
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec() + season_games * 7919
	var own_profile := {"rating": roundi(average_ovr()), "offense": 0.22, "defense": 0.22, "pace": 24, "three_rate": 0.36}
	var their_rating := int(opponent.get("rating", 70))
	var their_profile := {"rating": their_rating, "offense": 0.20, "defense": 0.20, "pace": 24, "three_rate": 0.34}
	var score: Array = MatchSimulator.game(own_profile, their_profile, rng)
	var won := int(score[0]) > int(score[1])
	var body := "練習結果：%d－%d · %s\n不影響 LP、資金、黃金、球探點與正式戰績。\n正式多人賽仍請按「隨機配對開打」，由伺服器結算。" % [int(score[0]), int(score[1]), "勝利" if won else "惜敗"]
	show_guide_sheet("快速練習", "%s · OVR %d" % [str(opponent.get("name", "對手")), their_rating], CYAN)
	var box: Node = guide_modal.find_child("GuideSheetBody", true, false) if is_instance_valid(guide_modal) else null
	if box != null:
		box.add_child(wrap_label(body, 15, TEXT, true))
		box.add_child(action_button("查看對手先發", CYAN, func():
			close_guide_modal()
			RankedFlow.show_lineup(self, opponent)
		, Vector2(0, 42)))

func prediction_key_for(opponent: Dictionary) -> String:
	return "%s:%s:%d" % [current_league, str(opponent.get("team_id", opponent.get("id", ""))), schedule_index]

func prediction_odds(opponent: Dictionary) -> Array[float]:
	var own := float(average_ovr())
	var their := float(opponent.get("rating", 70))
	var edge := clampf((their - own) / 30.0, -0.45, 0.45)
	return [clampf(1.55 + edge, 1.10, 2.20), clampf(1.55 - edge, 1.10, 2.20)]

func prediction_panel() -> Control:
	return callout("Pick'em 勝負預測", "目前沒有可預測賽事；官方賽程資料更新後會顯示在這裡。", GOLD)

func resolve_prediction(won: bool) -> void:
	if prediction_match_key.is_empty() or prediction_pick.is_empty() or prediction_stake <= 0:
		return
	var settled_match_id := prediction_match_key
	var margin := absi(last_score[0] - last_score[1])
	var actual := "1–5" if margin <= 5 else ("6–10" if margin <= 10 else ("11–20" if margin <= 20 else "21+"))
	var side_correct := (prediction_pick == "home" and won) or (prediction_pick == "away" and not won)
	var margin_correct := actual == prediction_margin
	if side_correct:
		prediction_correct += 1
		prediction_points += 10
		budget_million += prediction_stake * 2
		if margin_correct:
			prediction_points += 10
		if prediction_correct >= 10 and not prediction_badges.has("神算大師"):
			prediction_badges.append("神算大師")
		flash_notice("預測命中！積分 +%d" % (20 if margin_correct else 10))
	else:
		flash_notice("預測未命中，下注資金已結算")
	cloud_push_activity_leaderboard()
	cloud_push_prediction_result(settled_match_id)
	prediction_match_key = ""
	prediction_pick = ""
	prediction_margin = ""
	prediction_stake = 0

func cloud_push_activity_leaderboard() -> void:
	# Public rankings must be calculated by the server, never by client-supplied points.
	pass
func cloud_push_prediction(_match_id := "") -> void:
	# Real-fixture predictions remain closed until server deadline/settlement validation exists.
	pass

func cloud_push_prediction_result(_match_id := "") -> void:
	# Client simulations must not write real prediction results or public rankings.
	pass

func cloud_pull_activity() -> void:
	if auth_access.is_empty():
		return
	cloud_send("pull_activity_schedule", "%s/rest/v1/godot_activity_schedule?select=*&status=eq.scheduled&order=starts_at.asc&limit=50" % SUPABASE_URL, supabase_headers(true))
	cloud_send("pull_activity_leaderboard", "%s/rest/v1/godot_activity_leaderboard?select=*&order=prediction_points.desc&limit=20" % SUPABASE_URL, supabase_headers(true))

func show_daily_tasks() -> void:
	active_menu = "tasks"
	var content := begin_screen("任務", "每日 00:00（台灣時間）刷新 · 完成後獎勵會立即入帳", 4)
	var today := taiwan_today_key()
	var monthly_pending := monthly_pass_claimable_days(today) if monthly_pass_active else 0
	var claimed := daily_checkin_date == today or (monthly_pass_active and monthly_pending <= 0)
	var day_text := "%d／30 天" % daily_checkin_days
	var daily_text := "月卡已包含今日資源，不能重複領取" if monthly_pass_active else "今天完成：資金 +30 萬"
	content.add_child(callout("每日打卡", "%s\n累積進度：%s\n每日 00:00（台灣時間）刷新" % [daily_text, day_text], GOLD if not claimed else GREEN))
	var claim := action_button("今日打卡已完成" if claimed else "領取今日資金 +30 萬", GREEN if not claimed else Color("254e6b"), func():
		if monthly_pass_active:
			flash_notice("月卡已包含今日資源，不能重複領取")
			return
		if daily_checkin_date == taiwan_today_key():
			flash_notice("今天已領取，明天 00:00 後刷新")
			return
		daily_checkin_date = taiwan_today_key()
		daily_checkin_days = mini(30, daily_checkin_days + 1)
		daily_checkin_streak += 1
		budget_million += 30
		var bonus := ""
		if daily_checkin_days >= 30:
			gold += 100
			scout_points += 20
			daily_checkin_days = 0
			daily_checkin_streak = 0
			bonus = "，並獲得黃金 +100、球探點 +20"
		last_event = "每日打卡完成：資金 +30 萬%s。" % bonus
		last_news = last_event
		save_game()
		show_daily_tasks()
	, Vector2(0, 48))
	claim.text = "月卡已包含今日打卡" if monthly_pass_active else ("今日打卡已完成" if claimed else "領取今日資金 +30 萬")
	claim.disabled = claimed or monthly_pass_active
	content.add_child(claim)
	if monthly_pass_active:
		var pending_pass_days := monthly_pass_claimable_days(today)
		var pass_claimed := pending_pass_days <= 0
		content.add_child(callout("主場應援月卡 · 30 天簽到", "每日黃金 +50\n已領 %d／30 天；漏領黃金可累積。\n月影雲海限定球場已永久解鎖，可在球場展示自由切換。" % monthly_pass_claimed_days, GOLD if not pass_claimed else GREEN))
		var day_grid := GridContainer.new()
		day_grid.columns = 5
		day_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		day_grid.add_theme_constant_override("h_separation", 5)
		day_grid.add_theme_constant_override("v_separation", 5)
		for day in range(1, 31):
			var day_button := action_button("第 %d 天\n%s" % [day, "已領" if day <= monthly_pass_claimed_days else ("可補領" if day <= monthly_pass_claimed_days + pending_pass_days else "待領")], GREEN if day <= monthly_pass_claimed_days else (GOLD if day <= monthly_pass_claimed_days + pending_pass_days else Color("254e6b")), func(): pass, Vector2(0, 42))
			day_button.disabled = true
			day_grid.add_child(day_button)
		content.add_child(day_grid)
		var pass_button := action_button("月卡今日已領取" if pass_claimed else "領取月卡今日資源", GOLD if not pass_claimed else Color("254e6b"), func():
			var claim_days := monthly_pass_claimable_days(taiwan_today_key())
			if claim_days <= 0:
				flash_notice("月卡今日已領取")
				return
			monthly_pass_claimed_date = taiwan_today_key()
			# A monthly claim is also today's check-in; the free reward is locked
			# for this date so the two economy tracks can never stack.
			daily_checkin_date = monthly_pass_claimed_date
			monthly_pass_claimed_days = mini(30, monthly_pass_claimed_days + claim_days)
			gold += 50 * claim_days
			last_event = "月卡簽到完成 %d 天：黃金 +%d。" % [claim_days, 50 * claim_days]
			save_game()
			show_daily_tasks()
		, Vector2(0, 48))
		pass_button.disabled = pass_claimed or monthly_pass_claimed_days >= 30
		content.add_child(pass_button)
	content.add_child(action_button("查看長期挑戰", Color("254e6b"), func(): show_challenge_hub(), Vector2(0, 44)))

func show_challenge_hub() -> void:
	active_menu = "challenge"
	if mission_alert:
		mission_alert = false
		save_game()
	refresh_tactic_unlocks()
	var content := begin_screen("任務", "先選進攻或防守。打完對應場次才會進戰術頁。", 4)
	content.add_child(label("戰術任務", 18, GOLD, true))
	var tabs := HBoxContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tabs.add_theme_constant_override("separation", 8)
	content.add_child(tabs)
	tabs.add_child(action_button("進攻", TAIWAN_BLUE if tactic_kind_filter == "進攻" else Color("254e6b"), func():
		tactic_kind_filter = "進攻"
		show_challenge_hub()
	, Vector2(0, 40)))
	tabs.add_child(action_button("防守", TAIWAN_BLUE if tactic_kind_filter == "防守" else Color("254e6b"), func():
		tactic_kind_filter = "防守"
		show_challenge_hub()
	, Vector2(0, 40)))
	var shown := 0
	for item in locked_tactics():
		if str(item.get("kind", "")) != tactic_kind_filter:
			continue
		content.add_child(tactic_mission_card(item))
		shown += 1
	if shown == 0:
		content.add_child(callout("戰術", "這一側目前都已解鎖，可在編隊頁套用。", GREEN))
	content.add_child(label("挑戰劇本", 18, ORANGE, true))
	content.add_child(callout("目前進度", last_progress_event, GREEN))
	var cards := HBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cards.add_theme_constant_override("separation", 8)
	content.add_child(cards)
	for challenge_id in ["small_market", "salary_cap", "national_pride"]:
		cards.add_child(challenge_card(challenge_id))
	content.add_child(label("成就徽章", 18, GOLD, true))
	content.add_child(wrap_label("選擇最多兩枚，會顯示在頁面上方與對戰資訊；徽章只代表成就，不提供戰力。", 13, MUTED))
	var badge_grid := GridContainer.new()
	badge_grid.columns = 2 if is_handheld() else 3
	badge_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_grid.add_theme_constant_override("h_separation", 6)
	badge_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(badge_grid)
	for badge in ACHIEVEMENT_BADGES:
		var badge_id := str(badge.get("id", ""))
		var selected := equipped_badges.has(badge_id)
		var badge_button := action_button(("✓  " if selected else "○  ") + str(badge.get("name", "徽章")), GOLD if selected else Color("254e6b"), func(id := badge_id):
			toggle_equipped_badge(id)
		, Vector2(0, 40))
		badge_button.icon = load_png_tex("res://assets/art/badges/%s.png" % badge_id)
		badge_button.expand_icon = true
		badge_button.tooltip_text = str(badge.get("hint", ""))
		badge_grid.add_child(badge_button)

func toggle_equipped_badge(badge_id: String) -> void:
	if equipped_badges.has(badge_id):
		equipped_badges.erase(badge_id)
	else:
		if equipped_badges.size() >= 2:
			flash_notice("最多裝備兩枚徽章")
			return
		equipped_badges.append(badge_id)
	save_game()
	show_challenge_hub()

func equipped_badge_text() -> String:
	var names := PackedStringArray()
	for badge_id in equipped_badges:
		for badge in ACHIEVEMENT_BADGES:
			if str(badge.get("id", "")) == badge_id:
				names.append("◆ " + str(badge.get("name", "徽章")))
	return "　".join(names)

func tactic_mission_card(item: Dictionary) -> Control:
	var progress: Dictionary = item.get("progress", {"value": 0, "max": 1})
	var cur := float(progress.get("value", 0))
	var cap := maxf(1.0, float(progress.get("max", 1)))
	var shell := PanelContainer.new()
	shell.clip_contents = false
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", glass_style(16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	shell.add_child(padded(box, 14))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var title := wrap_label("%s · %s" % [item.get("kind", "戰術"), item.get("id", "")], 16, TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var count := plain_label("%d／%d" % [int(cur), int(cap)], 13, GOLD, true)
	count.size_flags_horizontal = Control.SIZE_SHRINK_END
	head.add_child(count)
	box.add_child(wrap_label(str(item.get("hint", "")), 13, MUTED, false))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = cap
	bar.value = cur
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	track.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	box.add_child(wrap_label(str(item.get("how", "")), 13, TEXT, false))
	box.add_child(wrap_label("克制：" + str(item.get("vs", "")), 13, CYAN, false))
	return shell

func challenge_card(challenge_id: String) -> Button:
	var selected := active_challenge == challenge_id
	var completed := bool(challenge_completed.get(challenge_id, false))
	var accent := GREEN if completed else (ORANGE if selected else CYAN)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 132 if compact_phone() else 154)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.text = ""
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", panel_style(Color("0d1c2bed"), accent.darkened(0.2), 15, 2 if selected else 1))
	button.add_theme_stylebox_override("hover", panel_style(Color("172e40f5"), accent, 15, 2))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	var margin := padded(box, 10)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(margin)
	box.add_child(plain_label("已完成" if completed else ("進行中" if selected else "可開始"), 11, accent, true))
	box.add_child(fit_label(challenge_label(challenge_id), 16 if compact_phone() else 18, TEXT, true))
	box.add_child(fit_label(challenge_story(challenge_id), 11, MUTED, false))
	box.add_child(fit_label(challenge_progress_text(challenge_id), 11, accent, false))
	button.pressed.connect(func(): show_challenge_detail(challenge_id))
	return button

func show_challenge_detail(challenge_id: String) -> void:
	var completed := bool(challenge_completed.get(challenge_id, false))
	var selected := active_challenge == challenge_id
	var reward_salary := 120 if challenge_id == "small_market" else (180 if challenge_id == "salary_cap" else 250)
	var reward_scout := 4 if challenge_id != "salary_cap" else 3
	var body := "%s\n\n任務條件：%s\n目前進度：%s\n完成獎勵：資金 +$%d 萬、球探點 +%d" % [challenge_story(challenge_id), challenge_description(challenge_id), challenge_progress_text(challenge_id), reward_salary, reward_scout]
	if completed:
		show_guide_sheet(challenge_label(challenge_id), body + "\n\n這項任務已完成。", GREEN)
	elif selected:
		show_guide_sheet(challenge_label(challenge_id), body + "\n\n目前正在進行這項任務。", ORANGE)
	else:
		show_guide_sheet(challenge_label(challenge_id), body, CYAN, "開始任務", func():
			close_guide_modal()
			select_challenge(challenge_id)
		)

func select_challenge(challenge_id: String) -> void:
	if bool(challenge_completed.get(challenge_id, false)):
		flash_notice("此挑戰已完成，可繼續用自由模式規劃下一季。")
		return
	active_challenge = challenge_id
	last_progress_event = "已選擇挑戰「%s」：%s" % [challenge_label(challenge_id), challenge_description(challenge_id)]
	save_game()
	show_challenge_hub()

func show_news_center() -> void:
	active_menu = "news"
	request_web_news(true)
	var content := begin_screen("新聞", "俱樂部賽程 + 每日真實聯盟新聞", 4)
	content.add_child(label("今日聯盟新聞", 18, GOLD, true))
	if web_news.is_empty():
		if OS.has_feature("web"):
			content.add_child(callout("網頁版新聞", "瀏覽器無法直接讀取 Google RSS；目前顯示下方俱樂部時間線。安裝版可更新公開新聞。", MUTED))
		else:
			content.add_child(callout("抓取中", "正在從公開新聞來源更新今日台籃消息。", MUTED))
	else:
		for item in web_news:
			if not (item is Dictionary):
				continue
			content.add_child(news_row(str(item.get("title", "新聞")), str(item.get("source", "公開來源")), CYAN, str(item.get("url", ""))))
	content.add_child(label("俱樂部時間線", 18, ORANGE, true))
	if news_feed.is_empty() and not last_news.is_empty():
		push_news(last_news)
	if news_feed.is_empty():
		content.add_child(callout("還沒有賽事", "打完第一場會留下下一場對手。", MUTED))
	else:
		for item in news_feed:
			if not (item is Dictionary):
				continue
			content.add_child(news_row(str(item.get("title", "賽事")), str(item.get("body", "")), GOLD))

func news_row(title: String, body: String, accent: Color, url := "") -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 78)
	row.clip_contents = false
	row.add_theme_stylebox_override("panel", panel_style(Color("0d1c2bed"), accent.darkened(0.25), 12, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	row.add_child(padded(box, 11))
	box.add_child(wrap_label(title, 14, accent, true))
	box.add_child(wrap_label(body if url.is_empty() else ("%s · 點開原文" % body), 12, TEXT, false))
	if not url.is_empty():
		var hit := Button.new()
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.flat = true
		hit.add_theme_stylebox_override("normal", invisible_style())
		hit.pressed.connect(func(): OS.shell_open(url))
		row.add_child(hit)
	return row

func decode_rss_text(raw: String) -> String:
	var cleaned := raw.strip_edges()
	cleaned = cleaned.replace("<![CDATA[", "").replace("]]>", "")
	return cleaned.xml_unescape().strip_edges()

func load_cached_web_news() -> void:
	if not FileAccess.file_exists(WEB_NEWS_PATH):
		return
	var file := FileAccess.open(WEB_NEWS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("items") is Array:
		var day := str(parsed.get("day", ""))
		if day == Time.get_date_string_from_system():
			web_news = parsed.items.duplicate(true)

func web_news_is_fresh() -> bool:
	if web_news.is_empty() or not FileAccess.file_exists(WEB_NEWS_PATH):
		return false
	var file := FileAccess.open(WEB_NEWS_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed is Dictionary and str(parsed.get("day", "")) == Time.get_date_string_from_system()

func request_web_news(refresh_view: bool) -> void:
	# Browsers block Google's RSS endpoint because it has no CORS opt-in. Do not
	# issue a request that is guaranteed to fail on every Web launch; cached and
	# in-game news remains available. Native builds can continue to fetch it.
	if OS.has_feature("web"):
		return
	if web_news_is_fresh():
		return
	if news_http == null:
		news_http = HTTPRequest.new()
		news_http.name = "NewsHttp"
		news_http.timeout = 18
		news_http.request_completed.connect(_on_web_news)
		add_child(news_http)
	if news_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	news_http.set_meta("refresh_view", refresh_view)
	var err := news_http.request(WEB_NEWS_RSS, PackedStringArray([
		"User-Agent: Mozilla/5.0 (compatible; TaiwanBasketballGM/1.0)",
		"Accept: application/rss+xml, application/xml, text/xml, */*",
	]))
	if err != OK and refresh_view:
		flash_notice("今日新聞暫時抓不到，稍後再開新聞頁。")

func _on_web_news(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code < 200 or code >= 300:
		return
	var xml := body.get_string_from_utf8()
	var items: Array = []
	var block := RegEx.new()
	block.compile("<item>([\\s\\S]*?)</item>")
	var title_re := RegEx.new()
	title_re.compile("<title>([\\s\\S]*?)</title>")
	var link_re := RegEx.new()
	link_re.compile("<link>([\\s\\S]*?)</link>")
	var source_re := RegEx.new()
	source_re.compile("<source[^>]*>([\\s\\S]*?)</source>")
	for found in block.search_all(xml):
		var chunk := found.get_string(1)
		var title_m := title_re.search(chunk)
		if title_m == null:
			continue
		var title := decode_rss_text(title_m.get_string(1))
		if title.is_empty() or title.contains("Google 新聞") or title.contains("Google News"):
			continue
		var link := ""
		var link_m := link_re.search(chunk)
		if link_m:
			link = decode_rss_text(link_m.get_string(1))
		var source := "公開新聞"
		var source_m := source_re.search(chunk)
		if source_m:
			var src := decode_rss_text(source_m.get_string(1))
			if not src.is_empty():
				source = src
		items.append({"title": title, "source": source, "url": link})
		if items.size() >= 8:
				break
	if items.is_empty():
		return
	web_news = items
	var file := FileAccess.open(WEB_NEWS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"day": Time.get_date_string_from_system(), "items": web_news}))
	if is_instance_valid(news_http) and bool(news_http.get_meta("refresh_view", false)) and active_menu == "news":
		show_news_center()

func national_candidates() -> Array[Dictionary]:
	return national_owned_players()

func show_national_team() -> void:
	apply_designer_unlocks()
	active_menu = "news"
	var event := national_event_data()
	var event_label := str(event.get("label", "中華隊"))
	if not extra_can_play("wcq") and not national_unlocked:
		var locked := begin_screen("中華隊", "先看賽程與名單", 4)
		locked.add_child(pending_unlock_box("1,200 黃金", "職業前二後即可解鎖出征"))
		locked.add_child(national_schedule_panel())
		if pro_top2:
			locked.add_child(action_button("前往商店 · 1,200 黃金", ORANGE, func(): select_store_product("賽事", "event_wcq"), Vector2(0, 52)))
		return
	if not national_unlocked:
		var pay := begin_screen("中華隊", "使用黃金永久解鎖資格賽", 4)
		pay.add_child(callout("代表隊", "已有前二資格。解鎖後依你擁有的名單打瓊斯盃與亞洲盃，組合 1.5 倍。", RED))
		pay.add_child(action_button("前往商店 · 1,200 黃金", ORANGE, func(): select_store_product("賽事", "event_wcq"), Vector2(0, 52)))
		return
	var content := begin_screen("代表隊", "%s · 擁有幾人算幾人" % event_label, 4)
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	content.add_child(picker)
	for item in career_rules.get("national_events", []):
		if not (item is Dictionary):
			continue
		var pick_id := str(item.get("id", ""))
		var pick_open := national_event_unlocked(pick_id)
		var caption := str(item.get("label", pick_id))
		picker.add_child(action_button(caption if pick_open else "%s鎖" % caption, TAIWAN_BLUE if national_event == pick_id else Color("254e6b"), func(id := pick_id):
			pick_national_event(id)
		, Vector2(0, 44)))
	var owned := national_owned_players()
	var bonus := national_combo_bonus()
	content.add_child(callout("組合", "擁有 %d／12 人。隊伍 +%d（國家隊 1.5 倍）。沒擁有的人不會自動補進名單。" % [owned.size(), bonus], GOLD))
	content.add_child(label(str(event.get("blurb", "")), 13, MUTED))
	national_roster.clear()
	for player in owned:
		national_roster.append(player)
		content.add_child(name_only_row(player))
	var missing: Array[String] = []
	for wanted in national_event_names():
		if owned_player_named(wanted).is_empty():
			missing.append(wanted)
	if not missing.is_empty():
		content.add_child(label("尚未擁有：%s" % "、".join(missing), 12, MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	actions.add_child(action_button("登錄名單", RED if not national_registered else Color("476354"), func(): register_national_team(), Vector2(0, 48)))
	actions.add_child(action_button("出征", ORANGE, func(): play_national_match(), Vector2(0, 48)))

func national_row(rank: int, player: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_stylebox_override("panel", panel_style(Color("160f18ed"), RED.darkened(0.3), 10, 1))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(padded(line, 7))
	line.add_child(label("%02d" % rank, 12, RED, true))
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(label("%s  ·  %s" % [player.get("name", "球員"), player.get("pos", "SG")], 14, TEXT, true))
	name_box.add_child(label("%s · OVR %d · 技能 %s" % [identity_label(player), int(player.get("ovr", 70)), player.get("skill_name", "即戰力")], 10, MUTED))
	line.add_child(name_box)
	return row

func pick_national_event(event_id: String) -> void:
	if not national_event_unlocked(event_id):
		flash_notice("先贏下目前這一屆才解鎖")
		return
	national_event = event_id
	national_registered = false
	national_roster.clear()
	show_national_team()

func register_national_team() -> void:
	var owned := national_owned_players()
	if owned.size() < 5:
		flash_notice("這一屆至少要擁有 5 名名單上的球員")
		return
	national_roster.clear()
	for player in owned:
		national_roster.append(player)
	national_registered = true
	national_last_result = "%s：%d 人已登錄。" % [national_event_data().get("label", "中華隊"), owned.size()]
	last_news = national_last_result
	save_game()
	show_national_team()

func play_national_match() -> void:
	if not national_registered:
		flash_notice("請先登錄目前擁有的中華隊名單")
		return
	var avg := 0.0
	for player in national_roster:
		avg += float(player.get("ovr", 70))
	avg /= maxi(national_roster.size(), 1)
	var core_bonus := float(national_combo_bonus())
	seed(national_games * 73 + int(avg * 11) + national_wins)
	var won := avg + core_bonus + randf_range(-4.0, 4.0) >= 76.0
	national_games += 1
	if won:
		national_wins += 1
		national_last_result = "中華隊擊敗對手，國際賽再添一勝。"
		budget_million += 90
		if national_event == "jones_white" and national_progress == "jones_white":
			national_progress = "jones_blue"
			national_event = "jones_blue"
			national_registered = false
			national_last_result += " 解鎖瓊斯盃中華藍。"
		elif national_event == "jones_blue" and national_progress == "jones_blue":
			national_progress = "asia_cup"
			national_event = "asia_cup"
			national_registered = false
			national_last_result += " 解鎖亞洲盃吉達。"
	else:
		national_last_result = "中華隊惜敗對手，下一場需要調整名單與戰術。"
	if active_challenge == "national_pride" and won:
		challenge_progress["national_pride"] = mini(challenge_target("national_pride"), int(challenge_progress.get("national_pride", 0)) + 1)
		complete_active_challenge("national_pride")
	else:
		last_progress_event = "中華隊國際賽結果已記錄。組合只算你擁有的名單人數。"
	last_news = national_last_result
	save_game()
	show_national_team()

func show_game_guide() -> void:
	active_menu = "guide"
	var content := begin_screen("遊戲指南", "點區塊看詳細說明", 4)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	grid.add_child(hub_tile("建隊", "取名 → 選 SBL 球星", "", CYAN, func(): show_guide_sheet("建隊", guide_topic_body("build"), CYAN), {}))
	grid.add_child(hub_tile("卡片等級", "青綠藍紅紫 · 金 · 鑽", "", PURPLE, func(): show_guide_sheet("卡片等級", guide_topic_body("cards"), PURPLE), {}))
	grid.add_child(hub_tile("先發前後場", "後場三人、前場兩人", "", ORANGE, func(): show_guide_sheet("先發前後場", guide_topic_body("lineup"), ORANGE), {}))
	grid.add_child(hub_tile("賽季", "%d 場例行賽 → 季後系列賽 → 冠軍" % regular_season_length(), "", ORANGE, func(): show_guide_sheet("賽季", guide_topic_body("season"), ORANGE), {}))
	grid.add_child(hub_tile("組合隊伍", "同出身 5／7／10／12 人", "", GOLD, func(): show_guide_sheet("組合隊伍", guide_topic_body("combo"), GOLD), {}))
	grid.add_child(hub_tile("外援", "各聯盟洋將上限不同", "", ORANGE, func(): show_guide_sheet("外援規定", guide_topic_body("foreign"), ORANGE), {}))
	grid.add_child(hub_tile("外籍生", "不佔外援名額", "", PURPLE, func(): show_guide_sheet("外籍生", guide_topic_body("student"), PURPLE), {}))
	grid.add_child(hub_tile("球探", "只用球探點挖掘", "", ORANGE, func(): show_guide_sheet("球探", guide_topic_body("scout"), ORANGE), {}))
	grid.add_child(hub_tile("交易與市場", "可多換一／自由簽約", "", GOLD, func(): show_guide_sheet("交易與市場", guide_topic_body("trade"), GOLD), {}))
	grid.add_child(hub_tile("比賽怎麼打", "回合模擬 · 平手延長賽", "", CYAN, func(): show_guide_sheet("比賽怎麼打", guide_topic_body("match"), CYAN), {}))
	grid.add_child(hub_tile("對手難度", "對手球員 OVR +5", "", RED, func(): show_guide_sheet("對手難度", guide_topic_body("difficulty"), RED), {}))
	grid.add_child(hub_tile("黃金與球探點", "兩套貨幣不要混", "", GOLD, func(): show_guide_sheet("黃金與球探點", guide_topic_body("gold"), GOLD), {}))
	grid.add_child(hub_tile("分享球員卡", "系統分享面板", "", GREEN, func(): show_guide_sheet("分享球員卡", guide_topic_body("share"), GREEN), {}))
	grid.add_child(hub_tile("額外比賽", "東超／瓊斯盃／資格賽", "", RED, func(): show_guide_sheet("額外比賽", guide_topic_body("extra"), RED), {}))
	grid.add_child(hub_tile("獎勵與存檔", "只有贏球才有獎勵", "", GREEN, func(): show_guide_sheet("獎勵與存檔", guide_topic_body("reward"), GREEN), {}))
	grid.add_child(hub_tile("聯賽規定", "SBL／PLG／TPBL 差在哪", "", CYAN, func(): show_guide_sheet("聯賽規定", guide_topic_body("league"), CYAN), {}))
	var tactic_guide := str(tactic_rules.get("guide", ""))
	if not tactic_guide.is_empty():
		content.add_child(hub_tile("勝負怎麼算", "點進去看對位", "", CYAN, func(): show_guide_sheet("勝負怎麼算", tactic_guide, CYAN), {}))

func close_guide_modal() -> void:
	if is_instance_valid(guide_modal):
		guide_modal.queue_free()
	guide_modal = null

func show_guide_sheet(title: String, body: String, accent: Color = GOLD, primary_text := "", primary_action := Callable()) -> void:
	close_guide_modal()
	var veil := ColorRect.new()
	guide_modal = veil
	veil.name = "GuideModal"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.03, 0.05, 0.72)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 50
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var sheet := PanelContainer.new()
	var wide := 520 if compact_phone() else 560
	sheet.custom_minimum_size = Vector2(wide, 280 if compact_phone() else 320)
	sheet.add_theme_stylebox_override("panel", panel_style(Color("0c1927fc"), accent, 18, 2))
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.name = "GuideBody"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	sheet.add_child(padded(box, 14))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var title_lab := label(title, 20, accent, true)
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	var close := action_button("關閉", Color("27394a"), func(): close_guide_modal(), Vector2(72, 44))
	close.add_theme_font_size_override("font_size", 22 if is_handheld() else 13)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 12 if is_handheld() else 0
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 160 if compact_phone() else 200)
	box.add_child(scroll)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 6)
	scroll.add_child(words)
	words.name = "GuideSheetBody"
	words.add_child(wrap_label(body, 14, TEXT, true))
	if not primary_text.is_empty() and primary_action.is_valid():
		var primary := gold_action_button(primary_text, primary_action)
		primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(primary)
	if title == "卡片等級":
		words.add_child(card_tier_legend())
	if title == "額外比賽":
		box.add_child(action_button("去打額外比賽", RED, func():
			close_guide_modal()
			show_extra_events()
		, Vector2(0, 44)))

func guide_topic_body(topic: String) -> String:
	match topic:
		"build":
			return "幫俱樂部取名後，從 SBL 公開名單選一位頭號球星當招牌。其餘先發會自動補位。隊名用官方名稱，球員能力是公開賽事數據原型，不是真實合約。"
		"cards":
			return "卡框顏色跟 OVR 走：青 65–70、綠 71–75、藍 76–80、紅 81–85、紫 86–90。特訓漲 OVR 會換卡色，年薪也會重抓。一般卡技能必須特訓 +5 才會在比賽生效，未解鎖仍會顯示技能說明。部分知名球星採用球迷熟悉的致敬名稱，例如 69大魔王、野獸覺醒、大房東收租與中華隊救星；名稱是遊戲化稱呼，不代表官方認定。其他致敬名稱包含台灣飛人、少俠出劍、阿美族戰士、寶島艾佛森、噴射機起飛、本土洋將、小鋼炮、高砲開火、黑豹突襲、安佛森變速、板凳核彈、鋒線萬用膠、冷面司令、台灣魔獸、台灣KD、球場魔術師、新北飆風玫瑰與中華隊最愛。金卡不看 OVR，只給黃金世代老將，一隊限 1 人。鑽卡是額外比賽冠軍或推薦滿人拿到的特殊卡，不能交易、不能刪除。同一人只能有一張（名單或保管箱）。任何管道取得已擁有的人都算重複卡，不進第二張，依卡色換成黃金：青 10、綠 15、藍 25、紅 40、紫 70、金 100、鑽石 120；跳出小視窗通知，原卡與訓練保留。沒有三張隨便合成養超模這條路。"
		"lineup":
			return "先發五人位置固定為 PG、SG、SF、PF、C，並標示後場／鋒線／前場。雙位置球員以資料中的第一位置作為主位置，第二位置須特訓 +5 後按下突破解鎖；未解鎖副位置使用時 OVR -5，已解鎖則不扣。完全錯位同樣 OVR -5，卡片會即時顯示修正後數字。點編隊裡兩張卡即可互換。名單不會從保管箱自動補回；登錄 7–12 人都能開打，名單越接近 12 人，輪替劣勢越小；12 人不扣輪替優勢。這不是直接扣除固定勝率。球員可以連續出賽，不需要等待恢復。"
		"season":
			return "遊戲例行賽 %d 場。%s。系列賽完成才開放選秀；下一季保留收藏與資源。" % [regular_season_length(), PlayoffSeries.rules(current_league).label]
		"combo":
			return "SBL 同隊登錄 5／7／10／12 人，全隊戰力 +1／+2／+3／+4；PLG、TPBL 同人數加成兩倍，為 +2／+4／+6／+8。所有鑽石卡免費算進任何隊伍組合，不必額外付款。黃金世代老將也算任何組合，一隊限 1 人。"
		"foreign":
			return "SBL 單洋將：註冊最多 1 名外援。PLG 註冊最多 3 名。TPBL 註冊 4 名、場上最多 2 人。超過就不能再簽。外援年薪較高，球探點也比較貴。黃金不能拿來墊薪資帽。"
		"student":
			return "外籍生（蓋比、阿美、伊波卡、石博恩這類）是紫色標籤，不佔外援名額，最多 2 人。跟本土、外援分開算。"
		"scout":
			return scout_rules_text()
		"trade":
			return "交易可一換一或多換一：點想換入的球員 → 選我方球員 → 確認。合計年薪須 ≥ 換入年薪，交易費另從資金扣除；交易後至少留 7 人。對手仍用原陣容。黃金卡與鑽石卡不進市場。自由簽約不必換人，簽約費為年薪 × 1.2（最低 45 萬），從資金扣除；年薪另外計入薪資帽，不扣黃金或球探點，仍須符合人數與外援限制。"
		"extra":
			return "額外比賽要先在 PLG 或 TPBL 例行賽打進前二。東超／BCL NT$100，瓊斯盃 NT$60，世界盃資格賽 NT$100。所有賽事先以預告表格呈現，你用原隊伍取代原本代表名額出賽：世界盃取代中華台北，瓊斯盃取代中華藍 A。拿到冠軍才送卡；冠軍卡不能交易、不能刪除。"
		"reward":
			return "每場結算資金：勝 +%d 萬、敗 +%d 萬（含額外比賽）。勝利黃金 5–10、球探點 1–3；勝利薪資帽 +20 萬與特訓 +1，連勝加成維持原設定。失敗仍有資金但不給黃金、球探點或特訓。SBL 薪資帽起始 3000 萬，PLG／TPBL 8000 萬。一般 SBL 卡年薪 50–300 萬，其他聯盟與特殊卡沿用原定價。" % [match_budget_reward(true), match_budget_reward(false)]
		"league":
			return "SBL：外援 1 人、場上最多 1 人、薪資帽 3000 萬。PLG：外援註冊 3 人、每節最多 2 人次，遊戲場上同時最多 2 人、帽 8000 萬。TPBL：外援註冊 4 人、場上同時最多 2 人，帽 8000 萬。外籍生三聯盟都最多 2、不佔洋將。職業前二才能買額外比賽通行證。"
		"match":
			return "雙方使用相同的回合模擬規則，投籃、失誤與進攻籃板共同形成比分，沒有固定分數區間。四節平手會進入延長賽，直到分出勝負。技能只由當節上場且已解鎖的球員觸發；一般卡須特訓 +5，紫卡、黃金卡與鑽石卡維持原規則。單張技能效果約控制在最多 6 個勝率百分點，全隊技能合計約最多 12 個百分點，不會取代 OVR。半場落後時可調整一次攻防戰術。系列賽對手輸球後可能調整防守，可在賽前查看。勝負看陣容、輪替、戰術對位與技能，也保留比賽的不確定性。"
		"difficulty":
			return "為了讓長期遊玩仍有挑戰，例行賽、季後賽與額外比賽的對手球員在本場複本中固定 OVR +5，隊伍評分同步提高。這項加成不會改動原始球員資料、玩家名單或存檔；同一場重複開啟畫面也不會再次累加。賽季難度等級原本的每級 +2 仍會保留，最高 +12。"
		"gold":
			return "資金用於簽約費、交易費與養成特訓（每次 20 萬＋1 特訓點，不使用黃金）。黃金用於商店卡包（80 黃金）與球探更換下一批（20 黃金）。球探點只用於購買球探卡片。薪資是名單已用年薪／上限，不是資金；簽約同時檢查資金和薪資帽。點上方資源即可查看明細或前往對應功能。"
		"share":
			return "分享會先做出球員卡圖，再叫出系統分享面板。iPhone 請在面板裡選 LINE，不要以為複製剪貼簿就算成功。電腦會打開圖檔，再用系統分享或貼上。"
		_:
			return ""

func card_tier_legend() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	var rows := [
		[
			{"key": "cyan", "mark": "青", "note": "65–70"},
			{"key": "green", "mark": "綠", "note": "71–75"},
			{"key": "blue", "mark": "藍", "note": "76–80"},
			{"key": "red", "mark": "紅", "note": "81–85"},
		],
		[
			{"key": "purple", "mark": "紫", "note": "86–90"},
			{"key": "gold", "mark": "金", "note": "老將"},
			{"key": "diamond", "mark": "鑽", "note": "冠軍卡"},
		],
	]
	for items in rows:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		for item in items:
			if not (item is Dictionary):
				continue
			var accent := tier_color(str(item.get("key", "cyan")))
			var chip := PanelContainer.new()
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chip.add_theme_stylebox_override("panel", panel_style(Color(accent.r, accent.g, accent.b, 0.18), accent, 10, 1))
			var words := VBoxContainer.new()
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			words.add_theme_constant_override("separation", 0)
			chip.add_child(padded(words, 6))
			words.add_child(plain_label(str(item.get("mark", "")), 14, accent, true, HORIZONTAL_ALIGNMENT_CENTER))
			words.add_child(plain_label(str(item.get("note", "")), 11, TEXT, false, HORIZONTAL_ALIGNMENT_CENTER))
			row.add_child(chip)
	return box

func extra_run(event_id: String) -> Dictionary:
	if event_id.is_empty():
		return {"entry": "", "wins": 0, "queue": []}
	if not extra_runs.has(event_id) or not (extra_runs[event_id] is Dictionary):
		extra_runs[event_id] = {"entry": "", "wins": 0, "queue": []}
	var run: Dictionary = extra_runs[event_id]
	if not run.has("records"):
		# Old saves only retain the active winning streak, not past losses/opponents.
		var known_wins := maxi(0, int(run.get("wins", 0)))
		run["records"] = {"club": {"w": known_wins, "l": 0, "last5": []}}
		run["legacy_record"] = known_wins > 0
		run["history"] = []
	return extra_runs[event_id]

func load_extra_run(event_id: String) -> void:
	extra_event = event_id
	var run := extra_run(event_id)
	extra_entry = str(run.get("entry", ""))
	extra_wins = int(run.get("wins", 0))
	extra_queue.clear()
	var bag = run.get("queue", [])
	if bag is Array:
		for item in bag:
			if item is Dictionary:
				extra_queue.append(item.duplicate(true))

func save_extra_run(event_id := "") -> void:
	var eid := event_id if not event_id.is_empty() else extra_event
	if eid.is_empty():
		return
	var run := extra_run(eid)
	if extra_event == eid:
		run["entry"] = extra_entry
		run["wins"] = extra_wins
		run["queue"] = extra_queue.duplicate(true)

func migrate_extra_runs_from_legacy() -> void:
	if extra_runs.is_empty() and (not extra_event.is_empty() or not extra_queue.is_empty() or not extra_entry.is_empty()):
		var eid := extra_event if not extra_event.is_empty() else "easl"
		extra_runs[eid] = {"entry": extra_entry, "wins": extra_wins, "queue": extra_queue.duplicate(true)}
		extra_run(eid)

func extra_events_footnote() -> String:
	for item in extra_event_catalog():
		var eid := str(item.get("id", ""))
		if not extra_runs.has(eid) or not (extra_runs[eid] is Dictionary):
			continue
		var run: Dictionary = extra_runs[eid]
		var bag = run.get("queue", [])
		if not str(run.get("entry", "")).is_empty() and bag is Array and bag.size() > 0:
			return "進行中 %s %d勝" % [str(item.get("title", eid)), int(run.get("wins", 0))]
	if extra_champions.get("easl", false) and extra_champions.get("bcl", false) and extra_champions.get("jones", false) and extra_champions.get("wcq", false):
		return "四冠都拿過"
	if not pro_top2:
		return "需職業前二"
	return "用我的球隊取代原名額"

func extra_event_data(event_id: String) -> Dictionary:
	for item in extra_event_catalog():
		if str(item.get("id", "")) == event_id:
			return item
	return {}

func extra_event_catalog() -> Array:
	return [
		{
			"id": "easl",
			"title": "東超 2025-26",
			"sku": "easl",
			"price": "900 黃金",
			"prize": "liu",
			"need": 3,
			"replace_id": "kings",
			"blurb": "東超預告：12 隊尚未開打。用我的球隊取代原本台灣代表名額，通行證 NT$100；冠軍送劉錚 OVR 85 SG 鑽石卡。",
			"teams": [
				{"id": "utsunomiya", "name": "宇都宮Brex", "rating": 86},
				{"id": "ryukyu", "name": "琉球金鋼", "rating": 84},
				{"id": "alvark", "name": "東京Alvark", "rating": 84},
				{"id": "pilots", "name": "桃園飛行員", "rating": 82},
				{"id": "sk_knights", "name": "首爾SK騎士", "rating": 82},
				{"id": "kings", "name": "新北皇家", "rating": 81},
				{"id": "fubon", "name": "台北悍將", "rating": 80},
				{"id": "changwon", "name": "昌原LG獵隼", "rating": 79},
				{"id": "manila", "name": "馬尼拉電訊閃電", "rating": 78},
				{"id": "ulanbaatar", "name": "烏蘭巴托Xac Broncos", "rating": 77},
				{"id": "hong_kong", "name": "香港東方", "rating": 74},
				{"id": "macau", "name": "澳門黑熊", "rating": 72},
			],
		},
		{
			"id": "bcl",
			"title": "BCL Asia 2025-26",
			"sku": "easl",
			"price": "900 黃金",
			"prize": "davis",
			"need": 3,
			"replace_id": "fubon",
			"blurb": "BCL Asia 預告：亞洲俱樂部賽尚未開打。用我的球隊取代原本台灣代表名額，通行證 NT$100；冠軍送戴維斯 OVR 86 C 鑽石卡。",
			"teams": [
				{"id": "fubon", "name": "台北悍將", "rating": 80},
				{"id": "kings", "name": "新北皇家", "rating": 81},
				{"id": "dreamers", "name": "寶島追逐者", "rating": 79},
				{"id": "ryukyu", "name": "琉球金鋼", "rating": 84},
				{"id": "alvark", "name": "東京Alvark", "rating": 84},
				{"id": "seoul", "name": "首爾三星雷霆", "rating": 78},
				{"id": "jakarta", "name": "印尼衛星隊", "rating": 76},
				{"id": "manila", "name": "馬尼拉電訊閃電", "rating": 78},
			],
		},
		{
			"id": "jones",
			"title": "2026 瓊斯盃",
			"sku": "jones",
			"price": "600 黃金",
			"prize": "hebo",
			"need": 3,
			"replay": true,
			"replace_id": "jones_blue",
			"blurb": "2026 瓊斯盃預告：8 隊尚未開打。我的球隊取代中華藍 A 名額，NT$60；冠軍送賀博 OVR 88 SG 鑽石卡。",
			"teams": [
				{"id": "jones_db", "name": "原州DB新世代", "rating": 84},
				{"id": "jones_uci", "name": "加州大學爾灣分校", "rating": 83},
				{"id": "jones_sga", "name": "菲律賓Strong Group", "rating": 82},
				{"id": "jones_japan", "name": "日本", "rating": 78},
				{"id": "jones_white", "name": "中華白", "rating": 76},
				{"id": "jones_jordan", "name": "約旦", "rating": 75},
				{"id": "jones_blue", "name": "中華藍", "rating": 74},
				{"id": "jones_mas", "name": "馬來西亞", "rating": 70},
			],
		},
		{
			"id": "wcq",
			"title": "世界盃資格賽",
			"sku": "national",
			"price": "1,200 黃金",
			"prize": "chen",
			"need": 3,
			"replace_id": "nt_taipei",
			"blurb": "2027 世界盃亞洲資格賽 B 組預告：賽事尚未開打。我的球隊取代中華台北資格，NT$100；冠軍送陳盈駿 OVR 85 PG 鑽石卡。",
			"teams": [
				{"id": "nt_japan", "name": "日本", "rating": 84},
				{"id": "nt_china", "name": "中國", "rating": 82},
				{"id": "nt_korea", "name": "韓國", "rating": 80},
				{"id": "nt_taipei", "name": "中華台北", "rating": 76},
			],
		},
	]

func extra_event_unlocked(event_id: String) -> bool:
	if event_id == "easl" or event_id == "bcl":
		return easl_pass
	if event_id == "jones":
		return jones_pass
	if event_id == "wcq":
		return national_unlocked
	return false

func extra_event_teams(event_id: String) -> Array:
	var data := extra_event_data(event_id)
	var result: Array = []
	var replace_id := str(data.get("replace_id", ""))
	for raw in data.get("teams", []):
		if not (raw is Dictionary):
			continue
		var team: Dictionary = raw.duplicate(true)
		if str(team.get("id", "")) == replace_id:
			team["id"] = "club"
			team["name"] = club_display_name()
			team["rating"] = int(round(average_ovr()))
			team["is_user"] = true
		else:
			team["players"] = extra_team_players(str(team.get("id", "")))
			var source_pack = extra_team_rosters.get(str(team.get("id", "")), {})
			if source_pack is Dictionary:
				team["source"] = str(source_pack.get("source", ""))
		result.append(team)
	return result

func extra_entry_label(event_id: String) -> String:
	match event_id:
		"wcq":
			return "我的球隊（取代中華台北資格）"
		"jones":
			return "我的球隊（取代中華藍 A）"
		_:
			return "我的球隊（台灣代表）"

func extra_preview_standings(event_id: String) -> Array:
	var rows: Array = []
	var run := extra_run(event_id)
	var records: Dictionary = run.get("records", {})
	var queue: Array = run.get("queue", [])
	for team in extra_event_teams(event_id):
		if not (team is Dictionary):
			continue
		var row: Dictionary = team.duplicate(true)
		var tid := str(row.get("id", ""))
		var record: Dictionary = records.get(tid, {})
		row["w"] = int(record.get("w", 0))
		row["l"] = int(record.get("l", 0))
		row["gb"] = "—"
		row["last5"] = " ".join(PackedStringArray(record.get("last5", [])))
		if str(row["last5"]).is_empty():
			row["last5"] = "—"
		row["next"] = "—"
		if not queue.is_empty():
			if tid == "club":
				row["next"] = str(queue[0].get("name", "對手"))
			elif tid == str(queue[0].get("id", "")):
				row["next"] = club_display_name()
		rows.append(row)
	return rows

func record_extra_result(won: bool) -> void:
	var run := extra_run(extra_event)
	var records: Dictionary = run.get("records", {})
	var opponent_id := str(last_opponent.get("team_id", last_opponent.get("id", "")))
	for tid in ["club", opponent_id]:
		if tid.is_empty():
			continue
		var record: Dictionary = records.get(tid, {"w": 0, "l": 0, "last5": []})
		var team_won := won if tid == "club" else not won
		var key := "w" if team_won else "l"
		record[key] = int(record.get(key, 0)) + 1
		var recent: Array = record.get("last5", [])
		recent.append("勝" if team_won else "敗")
		if recent.size() > 5:
			recent.pop_front()
		record["last5"] = recent
		records[tid] = record
	run["records"] = records
	var history: Array = run.get("history", [])
	history.append({"opponent": str(last_opponent.get("name", "對手")), "for": int(last_score[0]), "against": int(last_score[1]), "won": won})
	if history.size() > 30:
		history.pop_front()
	run["history"] = history

func extra_record_line(event_id: String) -> String:
	var record: Dictionary = extra_run(event_id).get("records", {}).get("club", {})
	return "累計 %d 勝 %d 敗" % [int(record.get("w", 0)), int(record.get("l", 0))]

func extra_prize_spec(prize_id: String) -> Dictionary:
	match prize_id:
		"liu":
			return {"name": "劉錚", "pos": "SG", "ovr": 85, "origin_team_id": "kings", "salary_million": 1800, "skill_id": "two_way_wing", "skill_name": "雙向側翼"}
		"davis":
			return {"name": "戴維斯", "pos": "C", "ovr": 86, "origin_team_id": "sbl_yulon", "salary_million": 1600, "skill_id": "glass_cleaner", "skill_name": "禁區卡位"}
		"chen":
			return {"name": "陳盈駿", "pos": "PG", "ovr": 85, "origin_team_id": "kings", "salary_million": 2800, "skill_id": "floor_general", "skill_name": "節奏大師"}
		"hebo":
			return {"name": "賀博", "pos": "SG", "ovr": 88, "origin_team_id": "fubon", "salary_million": 1200, "skill_id": "three_and_d", "skill_name": "定點砲台"}
		"lin":
			return {"name": "林書豪", "pos": "PG", "ovr": 90, "origin_team_id": "kings", "salary_million": 1000, "skill_id": "team_ovr_aura", "skill_name": "全隊加持", "combo_wild": true}
		_:
			return {}

func extra_prize_player(prize_id: String) -> Dictionary:
	var spec := extra_prize_spec(prize_id)
	if spec.is_empty():
		return {}
	var club := named_club_player(str(spec.get("name", "")))
	return stamp_prize_card(club, spec)

func extra_event_row(item: Dictionary) -> Control:
	var event_id := str(item.get("id", ""))
	var playable := extra_can_play(event_id)
	var champ := bool(extra_champions.get(event_id, false))
	var price := str(item.get("price", "NT$100"))
	var note := price
	if champ:
		note = "%s · 已奪冠" % price
	elif playable:
		note = "%s · 用我的球隊出賽" % price
	else:
		note = "待解鎖 · %s" % price
	var shell := PanelContainer.new()
	shell.clip_contents = false
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shell.custom_minimum_size = Vector2(0, 124 if is_handheld() else 152)
	if playable:
		shell.add_theme_stylebox_override("panel", glass_style(16))
	else:
		shell.add_theme_stylebox_override("panel", panel_style(Color("2c323ae8"), Color("8d97a4"), 16, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(fit_label(str(item.get("title", "")), 16 if compact_phone() else 18, GOLD if playable else MUTED, true))
	var flags := extra_event_flag_row(item)
	if flags != null:
		words.add_child(flags)
	words.add_child(fit_label(extra_record_line(event_id), 14, TEXT if playable else MUTED, false))
	words.add_child(fit_label(note, 13, CYAN if playable else MUTED, true))
	var prize := extra_prize_player(str(item.get("prize", "")))
	if not prize.is_empty():
		row.add_child(prize_side_card(prize, func():
			show_player_sheet(prize, func(): show_extra_events())
		))
	var wrap := padded(row, 8)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.z_index = 2
	var hit := hub_tile_hit(Color("8d97a4") if not playable else GOLD, false, func(): open_sub(show_extra_events, func(): try_open_extra(event_id)))
	hit.z_index = 0
	shell.add_child(hit)
	shell.add_child(wrap)
	bind_press_juice(shell, hit)
	return shell

func extra_event_flag_row(item: Dictionary) -> Control:
	var flags := HBoxContainer.new()
	flags.add_theme_constant_override("separation", 6)
	flags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shown := 0
	for team in extra_event_teams(str(item.get("id", ""))):
		if not (team is Dictionary):
			continue
		var logo_id := str(team.get("id", ""))
		flags.add_child(team_logo_rect(logo_id, 24, str(team.get("name", ""))))
		shown += 1
		if shown >= 8:
			break
	if shown == 0:
		return null
	return flags

func prize_side_card(player: Dictionary, action: Callable) -> Control:
	return lobby_player_card(player, false, -1, false, 55 if compact_phone() else 63, action)

func show_extra_events() -> void:
	active_menu = "more"
	var content := begin_screen("額外比賽", "獨立賽程與戰績 · 用自己的球隊挑戰", 4)
	if not extra_can_play("easl") and not extra_can_play("jones") and not extra_can_play("wcq"):
		content.add_child(label("參賽條件：職業例行賽前二＋賽事通行證。可先點選查看規則。", 14, MUTED))
	var events := GridContainer.new()
	events.columns = 2 if is_handheld() else 1
	events.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events.add_theme_constant_override("h_separation", 12)
	events.add_theme_constant_override("v_separation", 12)
	content.add_child(events)
	for item in extra_event_catalog():
		events.add_child(extra_event_row(item))

func try_open_extra(event_id: String) -> void:
	var data := extra_event_data(event_id)
	if data.is_empty():
		return
	show_extra_event(event_id)

func show_extra_event(event_id: String) -> void:
	var data := extra_event_data(event_id)
	if data.is_empty():
		show_extra_events()
		return
	load_extra_run(event_id)
	active_menu = "more"
	var content := begin_screen(str(data.get("title", "額外比賽")), extra_record_line(event_id), 4)
	var playable := extra_can_play(event_id)
	if not playable:
		content.add_child(pending_unlock_box(str(data.get("price", "")), "隊伍與賽程可以先看，解鎖後才能代表出賽"))
		if pro_top2 or designer_preview():
			var store_event_id := "event_jones" if event_id == "jones" else ("event_wcq" if event_id == "wcq" else "event_easl")
			content.add_child(action_button("%s 解鎖" % str(data.get("price", "黃金")), ORANGE, func(): select_store_product("賽事", store_event_id), Vector2(0, 48)))
	var champion := bool(extra_champions.get(event_id, false))
	var status_line := "本輪連勝 %d／%d · 輸球重新挑戰" % [extra_wins, int(data.get("need", 3))]
	if champion:
		status_line += " · 已領冠軍卡"
	content.add_child(label(status_line, 16, GOLD, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	actions.add_child(action_button("賽事規則與獎勵", Color("254e6b"), func():
		var prize := extra_prize_spec(str(data.get("prize", "")))
		show_guide_sheet(str(data.get("title", "額外比賽")), "%s\n連贏 %d 場奪冠；輸球重開一輪，累計戰績保留。\n通行證 %s。首冠獲得 %s 鑽石卡，只領一次，不能交易或刪除。\n這是遊戲挑戰賽程，並非即時官方積分。" % [extra_entry_label(event_id), int(data.get("need", 3)), str(data.get("price", "")), str(prize.get("name", "冠軍"))])
	))
	if playable:
		if not extra_queue.is_empty():
			actions.add_child(gold_action_button("賽前 · VS %s" % str(extra_queue[0].get("name", "對手")), func(): open_sub(func(): show_extra_event(event_id), show_extra_match_prep)))
		elif not champion or bool(data.get("replay", false)):
			actions.add_child(gold_action_button("免費再挑戰" if champion else "用我的球隊出賽", func(): pick_extra_entry(event_id, {})))
		else:
			content.add_child(label("本賽事已完成。", 14, MUTED))
	content.add_child(extra_event_preview_panel(event_id))

func extra_nation_tile(team: Dictionary, event_id: String) -> Control:
	var title := fictional_team_name(str(team.get("id", "")), str(team.get("name", "隊伍")))
	var flag_id := national_logo_id(str(team.get("id", "")), title)
	var hit := Button.new()
	hit.text = ""
	hit.custom_minimum_size = Vector2(0, 56 if compact_phone() else 64)
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", panel_style(Color(0.05, 0.08, 0.12, 0.72), CYAN.darkened(0.25), 12, 1))
	hit.add_theme_stylebox_override("hover", panel_style(Color(0.08, 0.11, 0.16, 0.4), CYAN, 12, 2))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(0.04, 0.06, 0.09, 0.8), TEXT, 12, 1))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	hit.add_child(row)
	row.add_child(team_logo_rect(flag_id, 40, title))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	words.add_child(plain_label(title, 15, TEXT, true))
	var sub := "戰力 %d · 點看真實名單" % int(team.get("rating", 75))
	if not extra_can_play(event_id):
		sub = "戰力 %d · 可先看名單" % int(team.get("rating", 75))
	words.add_child(plain_label(sub, 11, MUTED))
	var pick: Dictionary = team
	hit.pressed.connect(func():
		play_sfx("tap")
		show_extra_team_roster(pick, event_id)
	)
	bind_press_juice(hit, hit)
	return hit

func show_extra_team_roster(team: Dictionary, event_id: String) -> void:
	var players: Array = team.get("players", [])
	if players.is_empty():
		players = extra_team_players(str(team.get("id", "")))
	var lines := PackedStringArray()
	for raw in players:
		if raw is Dictionary:
			var player_ovr := str(raw.get("ovr", "—"))
			lines.append("%s　OVR %s　%s" % [str(raw.get("position", raw.get("pos", "—"))), player_ovr, str(raw.get("name", "球員"))])
	var body := "球隊戰力 %d · 名單 %d 人\n\n%s" % [int(team.get("rating", 75)), players.size(), "\n".join(lines)]
	var source := str(team.get("source", extra_team_rosters.get(str(team.get("id", "")), {}).get("source", "")))
	if not source.is_empty():
		body += "\n\n名單來源：%s" % source
	if players.is_empty():
		body += "\n\n尚未找到可核對的公開名單，不會冒用其他球隊球員。"
	if extra_can_play(event_id):
		show_guide_sheet(str(team.get("name", "隊伍")), body, CYAN, "用我的球隊開始賽事", func():
			close_guide_modal()
			pick_extra_entry(event_id, team)
		)
	else:
		show_guide_sheet(str(team.get("name", "隊伍")), body, CYAN)

func pick_extra_entry(event_id: String, team: Dictionary) -> void:
	load_extra_run(event_id)
	extra_event = event_id
	extra_entry = "club"
	extra_wins = 0
	extra_queue.clear()
	var data := extra_event_data(event_id)
	var replace_id := str(data.get("replace_id", ""))
	for other in extra_event_teams(event_id):
		if not (other is Dictionary):
			continue
		if bool(other.get("is_user", false)):
			continue
		var oid := str(other.get("id", ""))
		if oid.is_empty() or oid == "club" or oid == replace_id:
			continue
		extra_queue.append(other.duplicate(true))
	extra_queue.shuffle()
	while extra_queue.size() > int(data.get("need", 3)):
		extra_queue.remove_at(extra_queue.size() - 1)
	save_extra_run(event_id)
	save_game()
	show_extra_event(event_id)

func start_extra_match() -> void:
	if match_rewards_pending:
		show_match_presentation()
		return
	if extra_queue.is_empty():
		flash_notice("沒有下一場")
		return
	if team_players.size() < minimum_roster_to_play():
		flash_notice("至少保留 7 人才能開打，目前只有 %d 人。" % team_players.size())
		show_roster()
		return
	if not can_field_five():
		flash_notice(gameday_roster_warning())
		show_roster()
		return
	if over_salary_cap():
		flash_notice("已超薪資帽，先去編隊才能開打。")
		show_roster()
		return
	var opp: Dictionary = extra_queue[0]
	extra_match = true
	is_home_game = true
	last_opponent = extra_rival_from(opp)
	match_event_log.clear()
	current_skill_modifiers.clear()
	seed(Time.get_ticks_msec() + extra_wins * 91)
	match_defense_changed = false
	match_defense_menu = false
	quarter_scores = [[], []]
	quarter_stories.clear()
	match_threes = [0, 0]
	last_tactic_report = tactic_player_line(last_opponent)
	roll_match_rotation()
	roll_quarters_from(0)
	last_home_points = 2
	last_event = last_tactic_report
	last_news = last_event
	last_score = [0, 0]
	reveal_quarter = 0
	match_rewards_pending = true
	server_settlement_inflight = false
	server_settlement_ready = false
	server_settlement_balance.clear()
	server_settlement_match_id = ""
	save_game()
	play_sfx("whistle")
	show_match_presentation()

func finish_extra_match(won: bool) -> void:
	if not match_rewards_pending or not extra_match:
		return
	record_match_appearances()
	generate_box_sheet(int(last_score[0]))
	record_extra_result(won)
	var prize_note := ""
	var training_gain := 0
	if won:
		training_points += 1
		training_gain = 1
		extra_wins += 1
		if not extra_queue.is_empty():
			extra_queue.remove_at(0)
		last_event = "額外比賽贏了 %s。冠軍進度 %d，特訓點 +1。" % [last_opponent.get("name", "對手"), extra_wins]
		var need := int(extra_event_data(extra_event).get("need", 3))
		if extra_wins >= need:
			if not bool(extra_champions.get(extra_event, false)):
				extra_champions[extra_event] = true
				var prize_id := str(extra_event_data(extra_event).get("prize", ""))
				var spec := extra_prize_spec(prize_id)
				var duplicate_prize := team_has_player(stamp_prize_card({}, spec))
				grant_prize_card(prize_id)
				last_event += " 拿到冠軍！"
				prize_note = "%s 重複，已保留在保管箱" % str(spec.get("name", "球員")) if duplicate_prize else "獲得 %s 鑽石卡" % str(spec.get("name", "鑽石卡"))
			else:
				last_event += " 再挑戰完成。"
				prize_note = "本場沒有獲得"
		else:
			prize_note = "本場沒有獲得"
	else:
		extra_wins = 0
		extra_queue.clear()
		extra_entry = ""
		last_event = "額外比賽輸給 %s。再選隊伍重打。" % last_opponent.get("name", "對手")
		prize_note = "本場沒有獲得"
	var budget_gain := match_budget_reward(won)
	budget_million += budget_gain
	last_event += " 資金 +$%d 萬。" % budget_gain
	last_match_gain = {"won": won, "budget": budget_gain, "gold": 0, "scout": 0, "cap": 0, "train": training_gain, "extra": true, "event_id": extra_event, "note": prize_note}
	last_match_played = true
	last_progress_event = "三分 %d-%d · %s" % [match_threes[0], match_threes[1], last_tactic_report]
	save_extra_run(extra_event)
	extra_match = false
	match_rewards_pending = false
	push_news(last_event)
	save_game()

func grant_prize_card(prize_id: String, reveal := true) -> void:
	var spec := extra_prize_spec(prize_id)
	if spec.is_empty():
		return
	var fresh := stamp_prize_card({}, spec)
	if team_has_player(fresh):
		fresh["duplicate_pull"] = true
		card_inventory.append(fresh)
		duplicate_notices.append("%s → 重複卡已加入保管箱" % fresh.get("name", "球員"))
		call_deferred("show_duplicate_notice")
		return
	if can_sign_player(fresh).is_empty():
		team_players.append(fresh)
		apply_combo_label()
	else:
		card_inventory.append(fresh)
	if reveal:
		queue_card_reveal(fresh)

func stamp_prize_card(raw: Dictionary, spec: Dictionary) -> Dictionary:
	var card: Dictionary = to_game_player(raw) if not raw.is_empty() else to_game_player(spec)
	card["name"] = spec.get("name", card.get("name", "球員"))
	card["pos"] = spec.get("pos", "SG")
	card["position"] = card["pos"]
	card["ovr"] = int(spec.get("ovr", 85))
	card["origin_team_id"] = str(spec.get("origin_team_id", card.get("origin_team_id", "")))
	card["salary_million"] = int(spec.get("salary_million", card.get("salary_million", 1800)))
	card["skill_id"] = str(spec.get("skill_id", card.get("skill_id", "two_way_wing")))
	var profile: Dictionary = skill_profile(str(card.get("skill_id", "")))
	card["skill_name"] = str(spec.get("skill_name", profile.get("name", "即戰力")))
	card["skill_description"] = str(profile.get("description", card.get("skill_description", "")))
	card["locked_prize"] = true
	card["no_trade"] = true
	card["tier"] = "DIAMOND"
	card["color"] = "diamond"
	if bool(spec.get("combo_wild", false)) or bool(raw.get("combo_wild", false)):
		card["combo_wild"] = true
	if bool(raw.get("combo_flex_paid", false)):
		card["combo_flex_paid"] = true
		card["combo_flex_origin"] = str(raw.get("combo_flex_origin", ""))
		card["salary_million"] = int(raw.get("salary_million", card.get("salary_million", 0)))
	return card

func is_locked_prize(player: Dictionary) -> bool:
	return bool(player.get("locked_prize", false)) or str(player.get("tier", "")) == "DIAMOND"

func queue_card_reveal(player: Dictionary) -> void:
	if player.is_empty():
		return
	pending_card_reveal = player.duplicate(true)

func maybe_play_card_reveal(then := Callable()) -> void:
	if pending_card_reveal.is_empty():
		return
	var card := pending_card_reveal.duplicate(true)
	pending_card_reveal = {}
	show_card_reveal(card, then)

func close_card_reveal() -> void:
	var then_fn := card_reveal_then
	card_reveal_then = Callable()
	if is_instance_valid(card_reveal_modal):
		var old := card_reveal_modal
		card_reveal_modal = null
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
	if then_fn.is_valid():
		then_fn.call()

func card_reveal_kicker(player: Dictionary) -> String:
	if bool(player.get("duplicate_pull", false)):
		return "重複卡"
	if is_locked_prize(player) or str(player.get("tier", "")) == "DIAMOND":
		return "鑽石卡"
	var key := player_tier_key(player)
	match key:
		"gold":
			return "黃金世代"
		"red":
			return "明星卡"
		"purple":
			return "紫卡"
		"blue":
			return "稀有卡"
		_:
			return "獲得新卡"

func tier_display_name(key: String) -> String:
	match key:
		"cyan": return "灰色"
		"green": return "綠色"
		"blue": return "藍色"
		"red": return "紅色"
		"purple": return "紫色"
		"gold": return "金色"
		"diamond": return "鑽石"
		_: return "卡框"

func show_tier_up_reveal(player: Dictionary, old_tier: String, old_ovr: int, then := Callable()) -> void:
	close_share_sheet()
	if is_instance_valid(card_reveal_modal):
		card_reveal_then = Callable()
		close_card_reveal()
	card_reveal_then = then
	var new_tier := player_tier_key(player)
	var accent := tier_color(new_tier)
	var veil := ColorRect.new()
	card_reveal_modal = veil
	veil.name = "TierUpReveal"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.005, 0.01, 0.025, 0.90)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 72
	veil.set_meta("armed", false)
	add_child(veil)

	var flash := ColorRect.new()
	flash.color = Color(accent, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(flash)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 7)
	center.add_child(stack)
	var kicker := label("卡框升階", 22, accent.lightened(0.25), true, HORIZONTAL_ALIGNMENT_CENTER)
	kicker.modulate.a = 0.0
	stack.add_child(kicker)
	var card_w := 118 if compact_phone() else 154
	var card_h := int(round(float(card_w) / 0.68))
	var stage := Control.new()
	stage.name = "TierUpStage"
	stage.custom_minimum_size = Vector2(card_w, card_h)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = false
	stack.add_child(stage)

	var aura := ColorRect.new()
	aura.color = Color(accent, 0.28)
	aura.position = Vector2(-22, -22)
	aura.size = Vector2(card_w + 44, card_h + 44)
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.modulate.a = 0.0
	stage.add_child(aura)
	var old_player := player.duplicate(true)
	old_player["ovr"] = old_ovr
	old_player["color"] = old_tier
	var old_card := lobby_player_card(old_player, true, -1, false, card_w)
	old_card.name = "OldTierCard"
	old_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	old_card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	stage.add_child(old_card)
	var new_card := lobby_player_card(player, true, -1, false, card_w)
	new_card.name = "NewTierCard"
	new_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	new_card.scale = Vector2(0.86, 0.86)
	new_card.modulate.a = 0.0
	stage.add_child(new_card)
	var cracks := TierUpCracks.new()
	cracks.name = "TierUpCracks"
	cracks.accent = accent
	cracks.position = Vector2(-10, -8)
	cracks.size = Vector2(card_w + 20, card_h + 16)
	cracks.modulate.a = 0.0
	stage.add_child(cracks)
	var promotion := plain_label("%s → %s" % [tier_display_name(old_tier), tier_display_name(new_tier)], 17, accent.lightened(0.28), true, HORIZONTAL_ALIGNMENT_CENTER)
	promotion.modulate.a = 0.0
	stack.add_child(promotion)
	var ovr_text := plain_label("%s　OVR %d → %d" % [player.get("name", "球員"), old_ovr, int(player.get("ovr", old_ovr + 1))], 14, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	ovr_text.modulate.a = 0.0
	stack.add_child(ovr_text)
	var dismiss := plain_label("點畫面繼續", 12, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	dismiss.modulate.a = 0.0
	stack.add_child(dismiss)

	var cracks_tw := cracks.create_tween()
	cracks_tw.tween_property(cracks, "modulate:a", 1.0, 0.34).set_delay(0.12)
	cracks_tw.tween_property(cracks, "modulate:a", 0.0, 0.18)
	var old_tw := old_card.create_tween()
	old_tw.tween_property(old_card, "scale", Vector2(1.035, 1.035), 0.42).set_trans(Tween.TRANS_SINE)
	old_tw.tween_property(old_card, "modulate:a", 0.0, 0.12)
	var flash_tw := flash.create_tween()
	flash_tw.tween_property(flash, "color:a", 0.62, 0.08).set_delay(0.44)
	flash_tw.tween_property(flash, "color:a", 0.0, 0.20)
	var veil_ref: WeakRef = weakref(veil)
	get_tree().create_timer(0.48).timeout.connect(func():
		var live_veil = veil_ref.get_ref()
		if live_veil == null:
			return
		old_card.visible = false
		new_card.modulate.a = 1.0
		play_sfx("tier_up")
		if is_handheld():
			Input.vibrate_handheld(45, 0.55 if new_tier in ["green", "blue"] else 0.85)
		var reveal_tw := new_card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		reveal_tw.tween_property(new_card, "scale", Vector2(1.08, 1.08), 0.22)
		reveal_tw.tween_property(new_card, "scale", Vector2.ONE, 0.13)
		var shake_tw := stage.create_tween()
		shake_tw.tween_property(stage, "position:x", -6.0, 0.035).as_relative()
		shake_tw.tween_property(stage, "position:x", 11.0, 0.055).as_relative()
		shake_tw.tween_property(stage, "position:x", -7.0, 0.055).as_relative()
		shake_tw.tween_property(stage, "position:x", 2.0, 0.04).as_relative()
	)
	var info_tw := kicker.create_tween().set_parallel(true)
	info_tw.tween_property(kicker, "modulate:a", 1.0, 0.22).set_delay(0.52)
	info_tw.tween_property(promotion, "modulate:a", 1.0, 0.22).set_delay(0.56)
	info_tw.tween_property(ovr_text, "modulate:a", 1.0, 0.22).set_delay(0.62)
	info_tw.tween_property(dismiss, "modulate:a", 1.0, 0.18).set_delay(0.82)
	info_tw.tween_property(aura, "modulate:a", 0.86, 0.28).set_delay(0.48)
	var aura_tw := aura.create_tween().set_loops()
	aura_tw.tween_property(aura, "modulate:a", 0.30, 0.58).set_delay(0.78)
	aura_tw.tween_property(aura, "modulate:a", 0.78, 0.58)
	get_tree().create_timer(0.82).timeout.connect(func():
		var live_veil = veil_ref.get_ref()
		if live_veil != null:
			live_veil.set_meta("armed", true)
	)
	veil.gui_input.connect(func(event: InputEvent):
		if not bool(veil.get_meta("armed", false)):
			return
		if event is InputEventMouseButton and event.pressed:
			close_card_reveal()
		elif event is InputEventScreenTouch and event.pressed:
			close_card_reveal()
	)

func show_card_reveal(player: Dictionary, then := Callable(), note := "") -> void:
	close_share_sheet()
	if is_instance_valid(card_reveal_modal):
		card_reveal_then = Callable()
		close_card_reveal()
	card_reveal_then = then
	var veil := ColorRect.new()
	card_reveal_modal = veil
	veil.name = "CardReveal"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.01, 0.02, 0.05, 0.82)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 70
	veil.set_meta("armed", false)
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 8)
	center.add_child(stack)
	stack.add_child(label(card_reveal_kicker(player), 22, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var card_w := 118 if compact_phone() else 154
	var card_h := int(round(float(card_w) / 0.68))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(card_w, card_h)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = false
	stack.add_child(stage)
	var glow := ColorRect.new()
	glow.color = Color(0.96, 0.78, 0.32, 0.32)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -18
	glow.offset_top = -18
	glow.offset_right = 18
	glow.offset_bottom = 18
	stage.add_child(glow)
	var card := lobby_player_card(player, true, -1, false, card_w)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.08, 0.08)
	card.rotation = deg_to_rad(14)
	stage.add_child(card)
	stack.add_child(plain_label("%s · OVR %d" % [player.get("name", "球員"), int(player.get("ovr", 70))], 16, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	if not note.is_empty():
		stack.add_child(plain_label(note, 13, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(plain_label("點畫面收下", 12, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	play_sfx("new_card")
	var tw := card.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.42)
	tw.parallel().tween_property(card, "rotation", 0.0, 0.32)
	tw.chain().set_trans(Tween.TRANS_SINE)
	tw.tween_property(card, "scale", Vector2.ONE, 0.12)
	var gtw := glow.create_tween().set_loops()
	gtw.tween_property(glow, "modulate:a", 0.35, 0.55)
	gtw.tween_property(glow, "modulate:a", 0.95, 0.55)
	attach_share_fab(player_share_text(player, true), veil, 18, player)
	var veil_ref: WeakRef = weakref(veil)
	get_tree().create_timer(0.42).timeout.connect(func():
		var live_veil = veil_ref.get_ref()
		if live_veil != null:
			live_veil.set_meta("armed", true)
	)
	veil.gui_input.connect(func(event: InputEvent):
		if not bool(veil.get_meta("armed", false)):
			return
		if event is InputEventMouseButton and event.pressed:
			close_card_reveal()
		elif event is InputEventScreenTouch and event.pressed:
			close_card_reveal()
	)

func player_share_text(player: Dictionary, obtained := false) -> String:
	var kicker := "入手新卡！" if obtained else "我的球員卡"
	var skill := str(player.get("skill_name", "即戰力"))
	var help := combo_help_note(player)
	var extra := (" · " + help) if not help.is_empty() else ""
	return "【台籃模擬器】%s\n%s  %s  OVR %d%s\n技能：%s\n來討論這張卡怎麼用！" % [
		kicker,
		player.get("name", "球員"),
		position_mark(player),
		int(player.get("ovr", 70)),
		extra,
		skill,
	]

func combo_share_text() -> String:
	apply_combo_label()
	var names := combo_roster_names()
	var who := "、".join(names) if not names.is_empty() else "還沒湊滿組合"
	return "【台籃模擬器】組合隊伍總覽\n%s\n登錄：%s\n來社群討論怎麼組隊！" % [combo_rule_line(), who]

func combo_roster_names() -> PackedStringArray:
	var st := combo_progress_state()
	var origin := str(st.get("origin", ""))
	var names: PackedStringArray = []
	for i in mini(team_players.size(), gameday_limit()):
		var card: Dictionary = team_players[i]
		if is_combo_wild(card) or is_veteran_player(card) or (not origin.is_empty() and origin_id(card) == origin) or origin.is_empty():
			names.append(str(card.get("name", "球員")))
	return names

func social_share_targets() -> Array:
	return [
		{"id": "system", "name": "系統", "color": GOLD, "icon": "res://assets/ui/icons/save.png"},
		{"id": "line", "name": "LINE", "color": Color("06c755"), "icon": "res://assets/ui/logos/line.svg"},
		{"id": "facebook", "name": "Facebook", "color": Color("1877f2"), "icon": "res://assets/ui/logos/facebook.svg"},
		{"id": "instagram", "name": "Instagram", "color": Color("e1306c"), "icon": "res://assets/ui/logos/instagram.svg"},
		{"id": "threads", "name": "Threads", "color": Color("111111"), "icon": "res://assets/ui/logos/threads.svg"},
	]

func attach_share_fab(text: String, host: Control = null, extra_bottom := -1, share_player: Dictionary = {}) -> void:
	var parent := host if host != null else self
	var pad := screen_safe_pad()
	var nav := 0
	if extra_bottom >= 0:
		nav = extra_bottom
	elif current_stage >= 3 and current_stage < 6:
		nav = 70 if compact_phone() else 78
	var fab := Button.new()
	fab.name = "ShareFab"
	fab.text = "分享卡片" if not share_player.is_empty() else "分享"
	fab.z_index = 32
	fab.mouse_filter = Control.MOUSE_FILTER_STOP
	fab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fab.add_theme_font_size_override("font_size", 20 if is_handheld() else 14)
	fab.add_theme_color_override("font_color", Color("1a1408"))
	fab.add_theme_stylebox_override("normal", panel_style(GOLD, Color("fff3c4"), 18, 1))
	fab.add_theme_stylebox_override("hover", panel_style(Color("ffe08a"), TEXT, 18, 1))
	fab.add_theme_stylebox_override("pressed", panel_style(ORANGE, TEXT, 18, 1))
	fab.anchor_left = 1.0
	fab.anchor_top = 1.0
	fab.anchor_right = 1.0
	fab.anchor_bottom = 1.0
	var right := float(maxi(pad.z, 14) + 8)
	var bottom := float(maxi(pad.w, 12) + nav + 8)
	fab.offset_right = -right
	fab.offset_bottom = -bottom
	fab.offset_left = fab.offset_right - (168 if is_handheld() else 108)
	fab.offset_top = fab.offset_bottom - (80 if is_handheld() else 40)
	var captured := share_player.duplicate(true)
	fab.pressed.connect(func():
		play_sfx("tap")
		show_share_sheet(text, captured)
	)
	parent.add_child(fab)

func close_share_sheet() -> void:
	if is_instance_valid(share_modal):
		var old := share_modal
		share_modal = null
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
	share_modal = null

func show_share_sheet(text: String, share_player: Dictionary = {}) -> void:
	close_share_sheet()
	var veil := ColorRect.new()
	share_modal = veil
	veil.name = "ShareSheet"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.01, 0.02, 0.05, 0.45)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 85
	add_child(veil)
	veil.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close_share_sheet()
	)
	var pad := screen_safe_pad()
	var sheet := PanelContainer.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.anchor_left = 1.0
	sheet.anchor_top = 1.0
	sheet.anchor_right = 1.0
	sheet.anchor_bottom = 1.0
	# The share sheet is a modal and may safely sit above the persistent nav.
	# Reserving the full nav height made it extend past the top on compact
	# landscape phones (568x320).
	var nav := 12
	if is_instance_valid(card_reveal_modal):
		nav = 18
	var has_card := not share_player.is_empty()
	var view := get_viewport_rect().size
	sheet.offset_right = -float(maxi(pad.z, 12) + 8)
	sheet.offset_bottom = -float(maxi(pad.w, 12) + nav + 12)
	var sheet_width := 360.0 if compact_phone() else 400.0
	var requested_height := 296.0 if has_card and compact_phone() else (348.0 if has_card else 188.0)
	var max_height := maxf(180.0, view.y - float(pad.y + pad.w + nav + 20))
	sheet.offset_left = sheet.offset_right - minf(sheet_width, maxf(260.0, view.x - float(pad.x + pad.z + 16)))
	sheet.offset_top = sheet.offset_bottom - minf(requested_height, max_height)
	sheet.add_theme_stylebox_override("panel", panel_style(Color("0c1927fc"), GOLD, 16, 2))
	veil.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	sheet.add_child(padded(box, 10))
	box.add_child(label("分享球員卡圖到社群" if has_card else "分享到社群", 16, GOLD, true))
	if has_card:
		var preview := CenterContainer.new()
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.add_child(lobby_player_card(to_game_player(share_player), true, -1, false, 70 if compact_phone() else 86))
		box.add_child(preview)
		box.add_child(plain_label("打開系統分享，在面板裡選 LINE", 11, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for item in social_share_targets():
		if not (item is Dictionary):
			continue
		var target: Dictionary = item
		grid.add_child(social_share_chip(target, func(id := str(target.get("id", "line"))):
			share_to_network(id, text, share_player)
		))

func social_share_chip(target: Dictionary, action: Callable) -> Control:
	var caption := str(target.get("name", ""))
	var accent: Color = target.get("color", GOLD)
	var hit := Button.new()
	hit.text = ""
	hit.custom_minimum_size = Vector2(0, 64 if compact_phone() else 88)
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Dark material keeps white system icons and colored social marks readable
	# on both OLED phones and bright desktop previews.
	hit.add_theme_stylebox_override("normal", panel_style(Color("122333"), accent, 12, 1))
	hit.add_theme_stylebox_override("hover", panel_style(Color("1d354a"), GOLD, 12, 1))
	hit.add_theme_stylebox_override("pressed", panel_style(Color("0b1824"), TEXT, 12, 1))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 8
	col.offset_bottom = -6
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	hit.add_child(col)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(40, 40)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.texture = load_svg_tex(str(target.get("icon", "")), 128)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)
	if icon.texture == null:
		# SVG imports can be unavailable briefly on a first mobile launch. Keep
		# the target readable and tappable instead of showing a broken-image box.
		var fallback := label(caption.left(1), 20, accent, true, HORIZONTAL_ALIGNMENT_CENTER)
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(fallback)
	col.add_child(badge)
	var name_node := label(caption, 11, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	name_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_node)
	hit.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	return hit

func share_to_network(network: String, text: String, share_player: Dictionary = {}) -> void:
	var path := ""
	if not share_player.is_empty():
		if share_export_busy:
			return
		share_export_busy = true
		path = await render_player_share_png(share_player)
		share_export_busy = false
		if path.is_empty():
			flash_notice("球員卡圖沒存成")
			return
	if not path.is_empty() and try_system_share(path, text):
		close_share_sheet()
		return
	if not path.is_empty():
		copy_share_image_to_clipboard(path)
	if network == "system":
		flash_notice("這台裝置沒接到系統分享，已複製球員卡圖")
		close_share_sheet()
		return
	open_social_share(network, text, not path.is_empty())

func export_player_share_card(player: Dictionary) -> void:
	if share_export_busy:
		return
	share_export_busy = true
	var path := await render_player_share_png(player)
	share_export_busy = false
	if path.is_empty():
		flash_notice("球員卡圖沒存成")
		return
	if try_system_share(path, "%s OVR %d" % [player.get("name", "球員"), int(player.get("ovr", 70))]):
		return
	copy_share_image_to_clipboard(path)

func render_player_share_png(player: Dictionary) -> String:
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 640)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(400, 640)
	wrap.size = Vector2(400, 640)
	vp.add_child(wrap)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0b1522")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 24
	col.offset_right = -24
	col.offset_top = 20
	col.offset_bottom = -20
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(col)
	var kicker := Label.new()
	kicker.text = "台籃模擬器"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_override("font", FONT_BOLD)
	kicker.add_theme_font_size_override("font_size", 22)
	kicker.add_theme_color_override("font_color", GOLD)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(kicker)
	var card := lobby_player_card(to_game_player(player), true, -1, false, 220)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(card)
	var name_l := Label.new()
	name_l.text = "%s  %s  OVR %d" % [player.get("name", "球員"), position_mark(player), int(player.get("ovr", 70))]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_override("font", FONT_BOLD)
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", TEXT)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_l)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	vp.queue_free()
	if img == null or img.is_empty():
		return ""
	var path := "user://share_card.png"
	img.save_png(path)
	return path

func copy_share_image_to_clipboard(user_path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(user_path)
	var img := Image.new()
	if img.load(abs_path) != OK:
		return
	if DisplayServer.has_method("clipboard_set_image"):
		DisplayServer.call("clipboard_set_image", img)
		return
	if OS.get_name() == "macOS":
		OS.execute("/usr/bin/osascript", PackedStringArray([
			"-e",
			"set the clipboard to (read (POSIX file \"%s\") as «class PNGf»)" % abs_path
		]))

func try_system_share(user_path: String, text: String) -> bool:
	if user_path.is_empty() or not FileAccess.file_exists(user_path):
		return false
	var abs_path := ProjectSettings.globalize_path(user_path)
	if Engine.has_singleton("GodotShare"):
		var plug = Engine.get_singleton("GodotShare")
		if plug.has_method("share"):
			plug.share(text, abs_path)
			flash_notice("請在系統面板選 LINE")
			return true
	if OS.get_name() == "Android" and _android_share_image(abs_path, text):
		flash_notice("請在系統面板選 LINE")
		return true
	if OS.get_name() == "iOS" and _ios_share_image(abs_path, text):
		return true
	if OS.get_name() == "macOS":
		copy_share_image_to_clipboard(user_path)
		var opened := OS.shell_open(abs_path)
		if opened == OK:
			flash_notice("已打開球員卡圖，用系統分享送到 LINE")
			return true
	if OS.get_name() in ["Windows", "Linux"]:
		copy_share_image_to_clipboard(user_path)
		if OS.shell_open(abs_path) == OK:
			flash_notice("已打開球員卡圖，可再貼到 LINE")
			return true
	return false

func _ios_share_image(abs_path: String, text: String) -> bool:
	if Engine.has_singleton("InAppStore"):
		var store = Engine.get_singleton("InAppStore")
		if store.has_method("share"):
			store.share({"text": text, "image": abs_path})
			flash_notice("請在系統面板選 LINE")
			return true
	if _stage_ios_share_request(abs_path, text):
		flash_notice("請在系統面板選 LINE")
		return true
	copy_share_image_to_clipboard("user://share_card.png")
	if OS.shell_open(abs_path) == OK:
		flash_notice("已打開球員卡圖，按分享送到 LINE")
		return true
	return false

func _stage_ios_share_request(abs_path: String, text: String) -> bool:
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs.is_empty():
		return false
	var dest := docs.path_join("tb_share.png")
	if DirAccess.copy_absolute(abs_path, dest) != OK:
		return false
	var flag := FileAccess.open(docs.path_join("tb_share_go.txt"), FileAccess.WRITE)
	if flag == null:
		return false
	flag.store_string(text)
	return OS.get_name() == "iOS"

func _android_share_image(abs_path: String, text: String) -> bool:
	if not Engine.has_singleton("AndroidRuntime"):
		return false
	if not ClassDB.class_exists("JavaClassWrapper"):
		return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null or not runtime.has_method("getActivity"):
		return false
	var activity = runtime.getActivity()
	if activity == null:
		return false
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var FileCls = JavaClassWrapper.wrap("java.io.File")
	var FileProvider = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
	if Intent == null or FileCls == null or FileProvider == null:
		return false
	var intent = Intent.new()
	intent.setAction("android.intent.action.SEND")
	intent.setType("image/png")
	if not text.is_empty():
		intent.putExtra("android.intent.extra.TEXT", text)
	var file = FileCls.new(abs_path)
	# Android 7+ rejects file:// URIs (FileUriExposedException). Godot's
	# Android template already registers this FileProvider for the app.
	var authority := str(activity.getPackageName()) + ".fileprovider"
	var uri = FileProvider.getUriForFile(activity, authority, file)
	if uri == null:
		return false
	intent.putExtra("android.intent.extra.STREAM", uri)
	intent.addFlags(1) # FLAG_GRANT_READ_URI_PERMISSION
	var chooser = Intent.createChooser(intent, "分享球員卡")
	activity.startActivity(chooser)
	return true

func open_social_share(network: String, text: String, with_card := false) -> void:
	var enc := text.uri_encode()
	match network:
		"instagram":
			if not with_card:
				DisplayServer.clipboard_set(text)
			flash_notice("球員卡圖已複製，打開 Instagram 貼上" if with_card else "文案已複製，打開 Instagram 貼上")
			OS.shell_open("instagram://app")
		"line":
			if with_card:
				flash_notice("已複製球員卡圖，貼到 LINE")
			OS.shell_open("https://line.me/R/msg/text/?" + enc)
		"facebook":
			if with_card:
				flash_notice("球員卡圖已複製，貼到 Facebook 即可")
			OS.shell_open("https://www.facebook.com/sharer/sharer.php?quote=" + enc)
		"threads":
			if with_card:
				flash_notice("球員卡圖已複製，貼到 Threads 即可")
			OS.shell_open("https://www.threads.net/intent/post?text=" + enc)
		_:
			if not with_card:
				DisplayServer.clipboard_set(text)
			flash_notice("球員卡圖已複製" if with_card else "文案已複製")
	close_share_sheet()

func show_combo_overview() -> void:
	apply_combo_label()
	var st := combo_progress_state()
	var back_menu := active_menu
	active_menu = "roster" if back_menu == "roster" else "dashboard"
	var content := begin_screen("組合隊伍總覽", combo_rule_line(), 4)
	content.add_child(callout("加成", combo_bonus_headline(), GOLD if int(st.get("bonus", 0)) > 0 else CYAN))
	var origin := str(st.get("origin", ""))
	if not origin.is_empty():
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		content.add_child(head)
		head.add_child(team_logo_rect(origin, 36, str(st.get("label", ""))))
		head.add_child(label("%s · %d 人" % [st.get("label", "組合隊伍"), int(st.get("count", 0))], 18, TEXT, true))
	for i in mini(team_players.size(), gameday_limit()):
		var card: Dictionary = team_players[i]
		var mark := combo_help_note(card)
		content.add_child(hub_tile(str(card.get("name", "球員")), "%s · 基礎 OVR %d" % [position_mark(card), int(card.get("ovr", 70))], mark, GOLD, func(idx := i):
			show_owned_player(idx)
		, {}, true))
	content.add_child(gold_action_button("分享到社群討論", func(): show_share_sheet(combo_share_text()), Vector2(0, 48)))
	attach_share_fab(combo_share_text())

func screen_safe_pad() -> Vector4i:
	var pad := Vector4i(20, 10, 20, 24)
	if not is_handheld():
		return pad
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var keyboard := DisplayServer.virtual_keyboard_get_height()
	if keyboard > 0:
		safe = safe.intersection(Rect2(Vector2.ZERO, Vector2(win.x, maxf(1, win.y - keyboard))))
	return safe_pad_for_display(win, safe, get_viewport_rect().size)

func safe_pad_for_display(win: Vector2, safe: Rect2, design := Vector2(1280, 720)) -> Vector4i:
	var pad := Vector4i(20, 10, 20, 24)
	if win.x < 80.0 or win.y < 80.0 or safe.size.x < 8 or safe.size.y < 8:
		return pad
	var scale := minf(win.x / design.x, win.y / design.y)
	var shown := design * scale
	var canvas := Rect2((win - shown) * 0.5, shown)
	var hit := canvas.intersection(safe)
	if not hit.has_area():
		return pad
	pad.x = maxi(pad.x, ceili((hit.position.x - canvas.position.x) / scale))
	pad.y = maxi(pad.y, ceili((hit.position.y - canvas.position.y) / scale))
	pad.z = maxi(pad.z, ceili((canvas.end.x - hit.end.x) / scale))
	pad.w = maxi(pad.w, ceili((canvas.end.y - hit.end.y) / scale))
	return pad

func refresh_safe_margins() -> void:
	var pad := screen_safe_pad()
	if pad == _safe_pad_last:
		return
	_safe_pad_last = pad
	call_deferred("ensure_focused_field_visible")
	for margin in get_tree().get_nodes_in_group("screen_safe_margins"):
		if margin is MarginContainer and is_ancestor_of(margin):
			margin.add_theme_constant_override("margin_left", pad.x)
			margin.add_theme_constant_override("margin_top", pad.y)
			margin.add_theme_constant_override("margin_right", pad.z)
			margin.add_theme_constant_override("margin_bottom", pad.w)

func ensure_focused_field_visible() -> void:
	var field := get_viewport().gui_get_focus_owner()
	if not (field is LineEdit):
		return
	var parent := field.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(field)
			return
		parent = parent.get_parent()

func is_logged_in() -> bool:
	return not auth_access.is_empty()

func add_court_stage(dim_alpha := 0.4) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.clip_contents = false
	add_child(root)
	var court := TextureRect.new()
	court.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	court.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	court.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	court.mouse_filter = Control.MOUSE_FILTER_IGNORE
	court.texture = screen_arena_tex()
	if court.texture == null:
		court.texture = load_png_tex("res://assets/ui/half_court.png")
	root.add_child(court)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.06, 0.09, dim_alpha)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	return root

func glass_style(radius := 16) -> StyleBoxFlat:
	var style := panel_style(Color(0.05, 0.07, 0.11, 0.78), Color(0.96, 0.78, 0.32, 0.22), radius, 1)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style

func round_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	return panel_style(fill, border, radius, 1)

func hud_chip(text_value: String, accent: Color) -> PanelContainer:
	return resource_chip("", text_value, accent)

func resource_chip(title: String, value: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(Color(0.08, 0.1, 0.14, 0.78), accent.darkened(0.2), 12, 1))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	panel.add_child(padded(box, 8))
	if not title.is_empty():
		box.add_child(kicker_label(title, 9, MUTED))
	var node := number_label(value, 16, accent)
	node.custom_minimum_size = Vector2(96, 0)
	box.add_child(node)
	return panel

func salary_meter(width := 220) -> Control:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(width, 0)
	holder.clip_contents = true
	holder.add_theme_constant_override("separation", 3)
	var used := roster_salary()
	var cap := maxi(1, salary_cap)
	var ratio := clampf(float(used) / float(cap), 0.0, 1.0)
	var over := used > cap
	var headline := "%d／%d" % [used, cap]
	if width >= 160:
		headline = "薪資帽 %d／%d 萬" % [used, cap]
		if over:
			headline = "超支 %d／%d 萬" % [used, cap]
	elif over:
		headline = "超 %d／%d" % [used, cap]
	var cap_lab := kicker_label(headline, 11, RED if over else TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	cap_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(cap_lab)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = ratio
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 10)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	track.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GREEN if ratio < 0.85 else (GOLD if ratio < 1.0 else RED)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	holder.add_child(bar)
	return holder

func float_icon(caption: String, icon_id: String, accent: Color, action: Callable) -> Control:
	return nav_icon(caption, icon_id, false, action)

func show_entering(message := "正在進入…") -> void:
	clear_screen()
	current_stage = 0
	var root := add_court_stage(0.28)
	var loading := load_png_tex("res://assets/ui/hud/loading.png")
	if loading != null:
		var art := TextureRect.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.texture = loading
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(1, 1, 1, 0.88)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(art)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", glass_style(18))
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	sheet.add_child(padded(box, 28))
	box.add_child(polish_title(plain_label("台籃模擬器", 24, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)))
	box.add_child(kicker_label(message, 14, TEXT))
	if pending_enter_after_auth or not auth_access.is_empty():
		box.add_child(cloud_status_panel())
		box.add_child(action_button("先使用本機存檔", MUTED, func():
			cancel_cloud_requests()
			cloud_restore_incomplete = true
			pending_enter_after_auth = false
			continue_after_login()
		, Vector2(0, 40)))

func show_login() -> void:
	if current_stage != 0:
		match_play_id += 1
	clear_screen()
	current_stage = 0
	start_auth_listener()
	if login_email.is_empty() and not auth_email.is_empty():
		login_email = auth_email
	var view := get_viewport_rect().size
	var root := add_court_stage(0.42)
	var pad := screen_safe_pad()
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", pad.x)
	safe.add_to_group("screen_safe_margins")
	safe.add_theme_constant_override("margin_right", pad.z)
	safe.add_theme_constant_override("margin_top", pad.y)
	safe.add_theme_constant_override("margin_bottom", pad.w)
	root.add_child(safe)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_handheld():
		var form_scroll := ScrollContainer.new()
		form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		form_scroll.follow_focus = true
		form_scroll.scroll_deadzone = 12
		safe.add_child(form_scroll)
		form_scroll.add_child(center)
	else:
		safe.add_child(center)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(minf(760, usable_view().x - 20) if is_handheld() else clampf(view.x * 0.36, 340, 430), 0)
	sheet.clip_contents = true
	sheet.add_theme_stylebox_override("panel", glass_style(18))
	center.add_child(sheet)
	var page: BoxContainer = HBoxContainer.new() if is_handheld() else VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	sheet.add_child(page)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 6)
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.custom_minimum_size.x = 230 if is_handheld() else 0
	page.add_child(padded(brand, 22))
	var mark := TextureRect.new()
	mark.texture = load_png_tex("res://assets/ui/game_logo.png")
	mark.custom_minimum_size = Vector2(88, 88)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(mark)
	var kicker := kicker_label("TAIWAN BASKETBALL", 12, CYAN)
	kicker.add_theme_color_override("font_color", Color("8fe8ffcc"))
	brand.add_child(kicker)
	var title := polish_title(plain_label("台籃模擬器", 34, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	brand.add_child(title)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(72, 2)
	rule.color = GOLD
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	brand.add_child(rule)
	brand.add_child(label("登入可同步存檔", 13, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	brand.add_child(label("非官方籃球模擬遊戲\n無聯盟／球隊官方授權", 12, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	brand.add_child(legal_notice_button())
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	page.add_child(padded(body, 20))
	if is_logged_in():
		body.add_child(label(auth_email if not auth_email.is_empty() else "已登入", 13, GREEN, true, HORIZONTAL_ALIGNMENT_CENTER))
		# Re-run the release gate even when a session is already present.  This
		# prevents the remembered-session shortcut from bypassing maintenance or
		# a required minimum version.
		body.add_child(bind_account_button("進入球場", GOLD, Color("1a1200"), func(): enter_after_release_gate()))
		body.add_child(bind_account_button("登出", Color("3a2428"), TEXT, func(): logout_account()))
	else:
		var offline := bind_account_button("先離線遊玩（不需登入）", GOLD, Color("1a1200"), func(): continue_after_login())
		offline.name = "OfflinePlayButton"
		body.add_child(offline)
		body.add_child(bind_account_button("使用 Google 登入", Color("f4f4f4"), Color("111111"), func(): start_oauth("google"), "res://assets/ui/logos/google.svg"))
		if not OS.has_feature("web"):
			body.add_child(bind_account_button("使用 Apple 登入", Color("111111"), Color("f4f4f4"), func(): start_oauth("apple")))
		else:
			body.add_child(wrap_label("網頁版會使用安全的 HTTPS 回呼；若瀏覽器阻擋，請改用信箱驗證碼。", 18, MUTED))
		body.add_child(wrap_label("離線進度保存在此瀏覽器，請勿清除網站資料。" if OS.has_feature("web") else "離線進度只存在這台裝置，移除 App 會遺失。", 18, MUTED))
		body.add_child(label("或用信箱驗證碼", 12, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
		var mail := text_field("電子信箱", login_email)
		mail.custom_minimum_size = touch_minimum(Vector2(0, 40))
		mail.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
		mail.text_changed.connect(func(value: String): login_email = value.strip_edges())
		body.add_child(mail)
		var code := text_field("信件中的 6～10 位驗證碼", login_otp)
		code.custom_minimum_size = touch_minimum(Vector2(0, 40))
		code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		code.max_length = 10
		code.text_changed.connect(func(value: String): login_otp = value.strip_edges())
		body.add_child(code)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		body.add_child(row)
		row.add_child(bind_account_button("寄驗證碼", Color("254e6b"), TEXT, func(): send_gmail_otp()))
		row.add_child(bind_account_button("送出驗證碼", GOLD, Color("1a1200"), func(): verify_gmail_otp()))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	page.add_child(spacer)

func show_email_bind() -> void:
	show_login()
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	overlay.offset_top = -int(get_viewport_rect().size.y * 0.34)
	overlay.add_theme_stylebox_override("panel", panel_style(Color("1c1e22f8"), GOLD, 0, 0))
	add_child(overlay)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	overlay.add_child(padded(box, 12))
	var mail := text_field("Gmail 信箱", login_email)
	mail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mail.text_changed.connect(func(value: String): login_email = value.strip_edges())
	box.add_child(mail)
	var code := text_field("6 位數驗證碼", login_otp)
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code.text_changed.connect(func(value: String): login_otp = value.strip_edges())
	box.add_child(code)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(bind_account_button("寄驗證碼", Color("254e6b"), TEXT, func(): send_gmail_otp()))
	row.add_child(bind_account_button("送出驗證碼", CYAN, Color("111111"), func(): verify_gmail_otp()))

func bind_account_button(caption: String, fill: Color, font_color: Color, action: Callable, icon_path := "") -> Button:
	var button := Button.new()
	button.set_meta("light_surface", font_color.get_luminance() < 0.2)
	button.text = ""
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = touch_minimum(Vector2(0, 42))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", panel_style(fill, fill.darkened(0.08), 6, 0))
	button.add_theme_stylebox_override("hover", panel_style(fill.lightened(0.08), GOLD, 6, 1))
	button.add_theme_stylebox_override("pressed", panel_style(fill.darkened(0.12), TEXT, 6, 1))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	button.add_child(row)
	if not icon_path.is_empty():
		var badge := Control.new()
		badge.custom_minimum_size = Vector2(26, 26)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.texture = load_png_tex(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(icon)
		row.add_child(badge)
	var text_node := label(caption, 22 if is_handheld() else 15, font_color, true)
	text_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_node)
	button.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	bind_press_juice(button, button)
	return button

func start_new_game() -> void:
	reset_club_state()
	show_team_build()

func reset_club_state() -> void:
	playoff_state.clear()
	prep_extra_event = ""
	draft_state.clear()
	drafted_prospect_ids.clear()
	duplicate_notices.clear()
	phone_bench_scroll = 0
	active_save_slot = clampi(active_save_slot, 0, max_save_slots() - 1)
	match_play_id += 1
	_settling_match = false
	national_roster.clear()
	closer_name = ""
	last_box_sheet.clear()
	last_match_gain = {}
	news_feed.clear()
	league_table.clear()
	season_schedule.clear()
	schedule_index = 0
	team_players = []
	club_name = "未命名俱樂部"
	club_logo_id = "club_01"
	active_team_index = 0
	team_profiles = [{"name": club_name, "logo_id": club_logo_id, "players": []}, {}, {}]
	selected_foundation = 0
	selected_tactic = "快節奏轉換"
	selected_defense = "人盯人"
	is_home_game = true
	season_wins = 0
	season_losses = 0
	season_games = 0
	season_phase = "regular"
	current_league = "SBL"
	unlocked_leagues = ["SBL"]
	championships = {}
	unlocked_offense = ["快節奏轉換"]
	unlocked_defense = ["人盯人"]
	gold = int(career_rules.get("starter_gold", STARTING_GOLD))
	salary_cap_bonus = 0
	apply_salary_cap()
	card_inventory = []
	veteran_cleared = []
	coach_id = "sbl_rookie"
	coaches_owned = ["sbl_rookie"]
	national_unlocked = false
	combo_label = "尚未組成"
	tutorial_seen = false
	chemistry = 48
	budget_million = int(career_rules.get("starter_budget_million", STARTING_BUDGET_MILLION))
	economy_version = ECONOMY_VERSION
	scout_points = int(career_rules.get("starter_scout_points", STARTING_SCOUT_POINTS))
	scout_floor_game = -1
	training_points = STARTING_TRAINING_POINTS
	win_streak = 0
	gacha_candidates.clear()
	pro_top2 = false
	difficulty_level = 0
	extra_match = false
	extra_event = ""
	extra_entry = ""
	extra_wins = 0
	extra_queue.clear()
	extra_champions = {}
	extra_runs = {}
	national_event = "jones_white"
	national_progress = "jones_white"
	last_pro_league = "SBL"
	pending_enter_league = ""
	pending_path = ""
	opponent_index = 0
	last_score = [0, 0]
	quarter_scores = [[], []]
	quarter_stories = []
	match_threes = [0, 0]
	last_mvp = ""
	last_box = {"pts": 0, "reb": 0, "ast": 0}
	last_event = "從 SBL 開始。幫俱樂部取名，再選一位 SBL 頭號球星。"
	last_match_played = false
	match_rewards_pending = false
	last_skill_event = "先選球星，五人位置會自動補齊。"
	gacha_opened = 0
	scout_pity_progress = 0
	scout_board_serial = 0
	supporter_theme = "標準球館"
	store_cosmetics_owned = ["standard"]
	store_category = "精選"
	store_selected_product = "arena_taipei"
	home_environment_mode = "arena"
	locker_room_theme = "標準更衣室"
	vault_capacity_bonus = 0
	second_team_unlocked = false
	active_challenge = ""
	challenge_progress = {"small_market":0, "salary_cap":0, "national_pride":0}
	challenge_completed = {"small_market":false, "salary_cap":false, "national_pride":false}
	mission_alert = false
	daily_checkin_date = ""
	daily_checkin_streak = 0
	daily_checkin_days = 0
	monthly_pass_active = false
	monthly_pass_claimed_date = ""
	monthly_pass_claimed_days = 0
	scout_free_refresh_date = ""
	prediction_match_key = ""
	prediction_pick = ""
	prediction_margin = ""
	prediction_stake = 0
	prediction_points = 0
	prediction_correct = 0
	prediction_badges.clear()
	async_season_active = false
	async_season_game = 0
	async_season_wins = 0
	async_season_losses = 0
	async_season_points = 0
	async_season_roster_snapshot.clear()
	async_season_settled_key = ""
	last_progress_event = disclaimer_line()
	regular_wins = 0
	regular_losses = 0
	regular_games = 0
	veteran_mission = {"origin": "", "games": 0, "wins": 0, "stage": 0}
	last_opponent = {}
	national_registered = false
	national_games = 0
	national_wins = 0
	national_last_result = "尚未解鎖"
	current_skill_modifiers.clear()
	refresh_opponents(true)
	apply_designer_unlocks()


func show_save_slots() -> void:
	save_account()
	clear_screen()
	current_stage = 0
	var root := add_court_stage(0.4)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := screen_safe_pad()
	margin.add_theme_constant_override("margin_left", pad.x + 24)
	margin.add_theme_constant_override("margin_right", pad.z + 24)
	margin.add_theme_constant_override("margin_top", pad.y + 16)
	margin.add_theme_constant_override("margin_bottom", pad.w + 16)
	root.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	var head := VBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 4)
	page.add_child(head)
	head.add_child(label("選擇存檔", 22, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	head.add_child(label("點選繼續；左右滑動查看其他存檔", 13, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.name = "SaveSlotScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page.add_child(scroll)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	scroll.add_child(row)
	for i in mini(max_save_slots() + 1, 10):
		row.add_child(save_slot_card(i))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 10)
	page.add_child(foot)
	foot.add_child(action_button("登出", Color("3a2428"), func(): logout_account(), Vector2(120, 42)))

func save_slot_card(index: int) -> Control:
	var locked := index >= max_save_slots()
	var info := slot_preview(index)
	var occupied: bool = not bool(info.get("empty", true)) and not locked
	var shell := PanelContainer.new()
	shell.name = "SaveSlot%d" % index
	var card_size := Vector2(210, 232 if is_handheld() else 300)
	shell.custom_minimum_size = card_size
	shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var border := GOLD if occupied and index == active_save_slot else (MUTED if locked else Color(1, 1, 1, 0.22))
	shell.add_theme_stylebox_override("panel", panel_style(Color(0.06, 0.08, 0.11, 0.72), border, 18, 1))
	var stage := Control.new()
	stage.clip_contents = true
	stage.custom_minimum_size = card_size
	shell.add_child(stage)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = load_png_tex("res://assets/ui/half_court.png")
	art.modulate = Color(0.92, 0.94, 0.96, 1.0)
	stage.add_child(art)
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fade.offset_top = -150
	fade.color = Color(0.03, 0.04, 0.06, 0.88)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(fade)
	var plate := VBoxContainer.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	plate.offset_top = -142
	plate.offset_left = 12
	plate.offset_right = -12
	plate.offset_bottom = -12
	plate.add_theme_constant_override("separation", 4)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(plate)
	plate.add_child(label("第 %d 格" % (index + 1), 11, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	plate.add_child(label(str(info.get("club", "空檔")), 18, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	plate.add_child(label(str(info.get("line", "")), 12, GOLD, false, HORIZONTAL_ALIGNMENT_CENTER))
	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", panel_style(Color(1, 1, 1, 0.08), GOLD, 16, 0))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(1, 1, 1, 0.14), TEXT, 16, 0))
	hit.pressed.connect(func():
		play_sfx("tap")
		if locked:
			select_store_product("便利功能", "save_plus_1")
		else:
			open_save_slot(index)
	)
	bind_press_juice(shell, hit)
	stage.add_child(hit)
	return shell

func slot_preview(index: int) -> Dictionary:
	var locked := index >= max_save_slots()
	var row := {"slot": index, "empty": true, "club": "新球季", "line": "點這裡開打", "face": {}, "locked": locked}
	if locked:
		row["club"] = "第 %d 格" % (index + 1)
		row["line"] = "1,000 黃金解鎖"
		return row
	var path := slot_save_path(index)
	var parsed := SaveStore.read_save(path)
	if parsed.is_empty():
		return row
	row["empty"] = false
	row["club"] = str(parsed.get("club_name", "俱樂部"))
	row["line"] = "%s · %d勝%d敗" % [parsed.get("current_league", "SBL"), int(parsed.get("season_wins", 0)), int(parsed.get("season_losses", 0))]
	var roster = parsed.get("team_players", [])
	if roster is Array and not roster.is_empty() and roster[0] is Dictionary:
		row["face"] = roster[0]
	return row

func occupied_save_slots() -> Array:
	var found: Array = []
	for i in max_save_slots():
		if not bool(slot_preview(i).get("empty", true)):
			found.append(i)
	return found

func open_save_slot(index: int) -> void:
	if index < 0 or index >= max_save_slots():
		flash_notice("這個存檔格尚未解鎖")
		return
	active_save_slot = index
	save_account()
	if not SaveStore.read_save(slot_save_path(index)).is_empty():
		load_game(false)
		if match_rewards_pending:
			show_match_presentation()
		else:
			show_welcome_back()
	else:
		start_new_game()

func continue_after_login() -> void:
	var occupied := occupied_save_slots()
	if occupied.is_empty():
		if not auth_access.is_empty() and local_profile_id == auth_user_id and not LocalProfiles.legacy_slots().is_empty():
			LocalProfiles.show_import_offer(self)
			return
		start_new_game()
		return
	if occupied.size() == 1:
		open_save_slot(int(occupied[0]))
		return
	if occupied.has(active_save_slot):
		open_save_slot(active_save_slot)
		return
	show_save_slots()

func enter_after_release_gate() -> void:
	pending_enter_after_auth = true
	finish_auth_enter()

func show_welcome_back() -> void:
	welcome_open = true
	clear_screen()
	current_stage = 3
	var root := add_court_stage(0.44)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(420, 0)
	sheet.add_theme_stylebox_override("panel", glass_style(20))
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	sheet.add_child(padded(box, 28))
	box.add_child(label(club_name, 28, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(label("歡迎回來", 18, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(label("%s · %s" % [current_league, season_phase_label()], 13, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(action_button("進入大廳", ORANGE, func():
		welcome_open = false
		show_dashboard()
	, Vector2(220, 48)))
	var t := get_tree().create_timer(1.8)
	t.timeout.connect(func():
		if welcome_open and is_inside_tree() and current_stage == 3:
			welcome_open = false
			show_dashboard()
	)

func show_team_build() -> void:
	if club_name.strip_edges().is_empty() or club_name == "未命名俱樂部":
		club_name = default_club_name()
	var content := begin_screen("創立俱樂部", "從 SBL 開始 · " + disclaimer_line(), 1)
	content.add_child(callout("取名", "這是你的球會，不是真實職籃隊名。下一步選隊徽，再選一位 SBL 頭號球星。", CYAN))
	var bottom := PanelContainer.new()
	bottom.custom_minimum_size = Vector2(0, 56)
	bottom.add_theme_stylebox_override("panel", panel_style(Color("111c29ed"), GOLD, 12, 1))
	content.add_child(bottom)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	bottom.add_child(padded(bottom_row, 8))
	var name_input := text_field("俱樂部名稱 2–14 字", club_name)
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(func(value: String):
		if not value.strip_edges().is_empty():
			club_name = value.strip_edges()
	)
	bottom_row.add_child(name_input)
	bottom_row.add_child(action_button("去選隊徽", ORANGE, func():
		var typed := name_input.text.strip_edges()
		club_name = typed if not typed.is_empty() else default_club_name()
		if club_name.length() < 2:
			flash_notice("請先輸入至少 2 個字的俱樂部名稱")
		else:
			show_club_logo_picker(true)
	, Vector2(160, 48)))

func show_club_logo_picker(then_live := false) -> void:
	ensure_club_logo_id()
	var playing := not then_live and (current_stage >= 3 or not team_players.is_empty())
	var content := begin_screen("選擇隊徽", "大顆好點 · 選完就是你的球會標誌", 4 if playing else 1, playing)
	content.add_child(callout("觸控", "30 個原創隊徽，點一下就選。之後可在設定再換。", CYAN))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for item in CLUB_LOGOS:
		var logo_id := str(item.get("id", "club_01"))
		var picked := logo_id == club_logo_id
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		var hit := Button.new()
		hit.custom_minimum_size = Vector2(0, 78)
		hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hit.clip_contents = true
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var border := GOLD if picked else Color(0.35, 0.38, 0.42, 0.7)
		hit.add_theme_stylebox_override("normal", panel_style(Color(0.07, 0.08, 0.1, 0.9), border, 12, 2 if picked else 1))
		hit.add_theme_stylebox_override("hover", panel_style(Color(0.1, 0.11, 0.14, 0.95), GOLD, 12, 2))
		hit.add_theme_stylebox_override("pressed", panel_style(Color(0.05, 0.06, 0.08, 0.95), TEXT, 12, 2))
		var art := team_logo_rect(logo_id, 58, str(item.get("name", "")))
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 8
		art.offset_top = 6
		art.offset_right = -8
		art.offset_bottom = -6
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit.add_child(art)
		var captured := logo_id
		hit.pressed.connect(func():
			play_sfx("tap")
			club_logo_id = captured
			if then_live:
				show_live_selection()
			else:
				save_game()
				flash_notice("隊徽已換成「%s」" % club_logo_title())
				if playing:
					show_dashboard()
				else:
					show_club_logo_picker(false)
		)
		bind_press_juice(hit, hit)
		cell.add_child(hit)
		cell.add_child(kicker_label(str(item.get("name", "")), 10, GOLD if picked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(cell)
	if not then_live:
		content.add_child(action_button("返回", Color("254e6b"), func(): go_return_page() if playing else show_dashboard(), Vector2(0, 48)))

func show_live_selection() -> void:
	if live_choices.is_empty():
		for star in sbl_star_pool():
			if live_choices.size() >= 5:
				break
			var card := to_game_player(star)
			card["tier"] = "SBL STAR"
			live_choices.append(card)
		if live_choices.size() < 3:
			live_choices = default_starting_team()
	selected_live_player = ""
	var content := begin_screen("SBL 頭號球星", "選一位當開季招牌，其餘位置用 SBL 即戰力補齊", 2)
	content.add_child(callout("怎麼選", "不要只看 OVR。看位置與這季數據：你缺控球就拿組織，缺外線就拿砲台。", GREEN))
	var scroller := ScrollContainer.new()
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.custom_minimum_size = Vector2(0, 176)
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	content.add_child(scroller)
	var cards := HBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cards.add_theme_constant_override("separation", 10)
	scroller.add_child(cards)
	for i in live_choices.size():
		var idx := i
		var card := live_card_button(live_choices[i], i, func(index: int):
			var pick: Dictionary = live_choices[index]
			show_player_sheet(pick, func(): show_live_selection(), func(): choose_live_player(idx), "選他當頭號球星")
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
	content.add_child(label("點一張加入球隊", 13, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))

func choose_live_player(index: int) -> void:
	if index < 0 or index >= live_choices.size():
		return
	var player: Dictionary = live_choices[index]
	team_players = balanced_lineup([player])
	ensure_initial_roster()
	ensure_photographed_starters()
	apply_combo_label()
	last_skill_event = "%s 的招牌是「%s」" % [player.get("name", "球星"), player.get("skill_name", "即戰力")]
	selected_live_player = str(player.get("name", ""))
	chemistry = 52
	scout_points = int(career_rules.get("starter_scout_points", 20))
	scout_floor_game = -1
	ensure_club_name()
	last_event = "SBL 球星 %s 加盟 %s。先打完 %d 場例行賽。" % [player.get("name", "球星"), club_name, regular_season_length()]
	live_choices.clear()
	refresh_opponents(true)
	ensure_bench()
	apply_salary_cap()
	save_game()
	show_dashboard()
	show_card_reveal(player)

func show_dashboard() -> void:
	track_event("screen_dashboard", {"league": current_league, "season_phase": season_phase})
	prep_extra_event = ""
	if match_rewards_pending:
		show_match_presentation()
		return
	welcome_open = false
	active_menu = "dashboard"
	clear_return_stack()
	apply_salary_cap()
	ensure_initial_roster()
	ensure_season_scout()
	var renamed := club_name.strip_edges().is_empty() or club_name == "未命名俱樂部"
	ensure_club_name()
	if renamed:
		save_game()
	refresh_tactic_unlocks()
	if opponents.is_empty():
		refresh_opponents(true)
	elif season_schedule.is_empty() and season_phase == "regular":
		build_season_schedule()
	if league_table.is_empty():
		reset_league_table()
	ensure_bench()
	for i in team_players.size():
		if team_players[i] is Dictionary:
			team_players[i] = refresh_stored_player(team_players[i])
	ensure_photographed_starters()
	var opponent: Dictionary = current_match_opponent()
	build_dashboard_screen(opponent)
	maybe_show_tutorial()

func dashboard_skin(path: String) -> TextureRect:
	var skin := TextureRect.new()
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin.texture = load_png_tex(path)
	skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skin.stretch_mode = TextureRect.STRETCH_SCALE
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return skin

func home_header_resource(caption: String, value: String, icon_path: String, action: Callable) -> Button:
	var compact := compact_phone()
	var raw_number := int(value) if value.is_valid_int() else 0
	var shown_value := home_resource_number(raw_number) if value.is_valid_int() else value
	var button := action_button("", Color("00000000"), action, Vector2(60 if compact else 142, 44 if compact else 48))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_stretch_ratio = 1.75 if caption == "薪資空間" else 1.0
	button.add_theme_stylebox_override("normal", invisible_style())
	button.add_theme_stylebox_override("hover", panel_style(Color("ffffff0b"), GOLD, 10, 1))
	button.add_theme_stylebox_override("pressed", panel_style(Color("ffffff14"), GOLD, 10, 1))
	button.add_child(dashboard_skin("res://assets/ui/home/resource_pill_skin_trim_v1.png"))
	var icon := TextureRect.new()
	icon.texture = load_png_tex(icon_path)
	icon.anchor_left = 0.035
	icon.anchor_right = 0.22
	icon.anchor_top = 0.24
	icon.anchor_bottom = 0.78
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	# Two short rows remain readable on iPhone and leave the full width for long
	# balances. The previous single-line caption/value shrank to four pixels.
	var caption_label := fit_label(caption, 5 if compact else 6, Color("c5b98f"), true, HORIZONTAL_ALIGNMENT_LEFT)
	caption_label.anchor_left = 0.24
	caption_label.anchor_right = 0.83
	caption_label.anchor_top = 0.04
	caption_label.anchor_bottom = 0.36
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption_label)
	var balance := fit_label(shown_value, 7 if compact else 9, Color("fff2c2"), true, HORIZONTAL_ALIGNMENT_LEFT)
	balance.anchor_left = 0.24
	balance.anchor_right = 0.95 if caption in ["資金", "薪資空間"] else 0.83
	balance.anchor_top = 0.46
	balance.anchor_bottom = 0.96
	balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(balance)
	var plus := plain_label("＋", 9 if compact else 13, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	plus.anchor_left = 0.84
	plus.anchor_right = 0.96
	plus.anchor_top = 0.1
	plus.anchor_bottom = 0.9
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plus.visible = caption not in ["資金", "薪資空間"]
	button.add_child(plus)
	button.tooltip_text = "%s：%s" % [caption, value]
	return button

func home_resource_number(value: int) -> String:
	var amount := maxi(value, 0)
	if amount >= 100000000:
		return ("%.1f億" % (float(amount) / 100000000.0)).replace(".0億", "億")
	if amount >= 10000000:
		return "%d萬" % int(round(float(amount) / 10000.0))
	if amount >= 10000:
		return ("%.1f萬" % (float(amount) / 10000.0)).replace(".0萬", "萬")
	return str(amount)

func dashboard_scene_shortcut(caption: String, action: Callable, left: float, right: float, top: float) -> Button:
	var button := action_button(caption, Color("0a1019dd"), action, Vector2(64 if compact_phone() else 135, 38 if compact_phone() else 44))
	button.anchor_left = left
	button.anchor_right = right
	button.anchor_top = top
	button.anchor_bottom = top
	button.offset_top = 0
	button.offset_bottom = 38 if compact_phone() else 44
	button.add_theme_font_size_override("font_size", 11 if compact_phone() else 16)
	button.add_theme_stylebox_override("normal", panel_style(Color("080d15d8"), GOLD, 7, 1))
	button.add_theme_stylebox_override("hover", panel_style(Color("211b0de8"), Color("ffe49a"), 7, 2))
	button.tooltip_text = caption
	return button

func dashboard_fade_texture(left_color: Color, middle_color: Color, right_color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.64, 1.0])
	gradient.colors = PackedColorArray([left_color, middle_color, right_color])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 640
	texture.height = 96
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

func home_next_match_strip(opponent: Dictionary) -> Control:
	var compact := compact_phone()
	var panel := PanelContainer.new()
	panel.name = "HomeNextMatchStrip"
	panel.add_theme_stylebox_override("panel", panel_style(Color("d6e0ea1c"), Color("e2cc805f"), 9, 1))
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", -1 if compact else 1)
	panel.add_child(padded(content, 4 if compact else 7))
	content.add_child(kicker_label("下一場 · %s" % fixture_label(), 8 if compact else 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5 if compact else 9)
	content.add_child(row)
	row.add_child(team_logo_rect(ensure_club_logo_id(), 26 if compact else 38, club_display_name()))
	row.add_child(fit_label(club_display_name(), 9 if compact else 13, TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(plain_label("VS", 10 if compact else 15, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var rival_id := str(opponent.get("team_id", opponent.get("id", "")))
	var rival_name := str(opponent.get("name", "待定對手"))
	row.add_child(team_logo_rect(rival_id, 26 if compact else 38, rival_name))
	row.add_child(fit_label(rival_name, 9 if compact else 13, TEXT, true))
	var hit := action_button("", Color("00000000"), func(): show_match_prep(), Vector2.ZERO)
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.tooltip_text = "查看下一場：%s vs %s" % [club_display_name(), rival_name]
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", panel_style(Color("ffffff0c"), GOLD, 9, 1))
	panel.add_child(hit)
	return panel

func dashboard_schedule_entry(relative_index: int, fallback: Dictionary) -> Dictionary:
	if season_schedule.is_empty():
		return {"team": fallback, "number": 1, "home": is_home_game}
	var position := posmod(schedule_index + relative_index, season_schedule.size())
	var raw = season_schedule[position]
	if raw is not Dictionary:
		return {"team": fallback, "number": position + 1, "home": true}
	var game: Dictionary = raw
	var team = game.get("team", fallback)
	return {"team": team if team is Dictionary else fallback, "number": position + 1, "home": bool(game.get("home", true))}

func dashboard_schedule_card(entry: Dictionary, highlighted: bool, tilt_degrees: float) -> PanelContainer:
	var compact := compact_phone()
	var team: Dictionary = entry.get("team", {})
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(66 if highlighted and compact else (52 if compact else (150 if highlighted else 124)), 92 if highlighted and compact else (78 if compact else (178 if highlighted else 150)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if highlighted else Control.SIZE_SHRINK_CENTER
	card.rotation = deg_to_rad(tilt_degrees)
	card.pivot_offset = card.custom_minimum_size * 0.5
	var bg_color := Color("e9d28df2") if highlighted else Color("09121ee9")
	var border := Color("fff0b5") if highlighted else Color("8f794eaa")
	card.add_theme_stylebox_override("panel", panel_style(bg_color, border, 8, 2 if highlighted else 1))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0 if compact else 3)
	card.add_child(padded(box, 3 if compact else 6))
	var ink := Color("17130c") if highlighted else TEXT
	box.add_child(plain_label("第 %d 場" % int(entry.get("number", 1)), 7 if compact else 10, ink, true, HORIZONTAL_ALIGNMENT_CENTER))
	var team_id := str(team.get("team_id", team.get("id", "")))
	var team_name := str(team.get("name", "待定對手"))
	box.add_child(team_logo_rect(team_id, 28 if compact else (64 if highlighted else 54), team_name))
	var name_label := fit_label(team_name, 8 if compact else 12, ink, true, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.tooltip_text = team_name
	box.add_child(name_label)
	if highlighted:
		box.add_child(plain_label("主場" if bool(entry.get("home", true)) else "客場", 7 if compact else 9, Color("725012"), true, HORIZONTAL_ALIGNMENT_CENTER))
	return card

func shift_home_schedule_preview(delta: int) -> void:
	if season_schedule.is_empty():
		return
	home_schedule_preview_offset = posmod(home_schedule_preview_offset + delta, season_schedule.size())
	show_dashboard()

func dashboard_schedule_hotspot(delta: int, tip: String) -> Control:
	var hotspot := Control.new()
	hotspot.mouse_filter = Control.MOUSE_FILTER_STOP
	hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hotspot.tooltip_text = tip
	hotspot.gui_input.connect(func(event: InputEvent):
		var activate: bool = false
		if event is InputEventMouseButton:
			activate = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		elif event is InputEventScreenTouch:
			activate = event.pressed
		if activate:
			hotspot.accept_event()
			play_sfx("tap")
			shift_home_schedule_preview(delta)
	)
	return hotspot

func dashboard_schedule_card_content(entry: Dictionary, highlighted: bool, left: float, right: float) -> Control:
	var compact := compact_phone()
	var team: Dictionary = entry.get("team", {})
	var holder := Control.new()
	holder.anchor_left = left
	holder.anchor_right = right
	holder.anchor_top = 0.18 if highlighted else 0.22
	holder.anchor_bottom = 0.72
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -2 if compact else 1)
	holder.add_child(box)
	var ink := Color("17130c") if highlighted else TEXT
	box.add_child(plain_label("第 %d 場" % int(entry.get("number", 1)), 6 if compact else 8, ink, true, HORIZONTAL_ALIGNMENT_CENTER))
	var team_id := str(team.get("team_id", team.get("id", "")))
	var team_name := str(team.get("name", "待定對手"))
	box.add_child(team_logo_rect(team_id, 21 if compact else (44 if highlighted else 37), team_name))
	var name_label := fit_label(team_name, 6 if compact else 8, ink, true, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.tooltip_text = team_name
	box.add_child(name_label)
	if highlighted:
		box.add_child(plain_label("主場" if bool(entry.get("home", true)) else "客場", 5 if compact else 7, Color("725012"), true, HORIZONTAL_ALIGNMENT_CENTER))
	return holder

func home_schedule_carousel(opponent: Dictionary) -> Control:
	var compact := compact_phone()
	var shell := Control.new()
	shell.name = "HomeScheduleCarousel"
	var skin := TextureRect.new()
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin.texture = load_png_tex("res://assets/ui/home/schedule_carousel_skin_v2.png")
	skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skin.stretch_mode = TextureRect.STRETCH_SCALE
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(skin)
	var heading := fit_label("下一場" if home_schedule_preview_offset == 0 else "賽程預覽", 10 if compact else 16, GOLD, true)
	heading.anchor_left = 0.08
	heading.anchor_right = 0.38
	heading.anchor_top = 0.025
	heading.anchor_bottom = 0.16
	shell.add_child(heading)
	var previous := dashboard_schedule_hotspot(-1, "上一場賽程")
	previous.anchor_left = 0.035
	previous.anchor_right = 0.12
	previous.anchor_top = 0.37
	previous.anchor_bottom = 0.62
	shell.add_child(previous)
	var following := dashboard_schedule_hotspot(1, "下一場賽程")
	following.anchor_left = 0.88
	following.anchor_right = 0.965
	following.anchor_top = 0.37
	following.anchor_bottom = 0.62
	shell.add_child(following)
	shell.add_child(dashboard_schedule_card_content(dashboard_schedule_entry(home_schedule_preview_offset - 1, opponent), false, 0.14, 0.385))
	shell.add_child(dashboard_schedule_card_content(dashboard_schedule_entry(home_schedule_preview_offset, opponent), true, 0.385, 0.64))
	shell.add_child(dashboard_schedule_card_content(dashboard_schedule_entry(home_schedule_preview_offset + 1, opponent), false, 0.64, 0.875))
	var center_entry := dashboard_schedule_entry(home_schedule_preview_offset, opponent)
	var rival: Dictionary = center_entry.get("team", opponent)
	var matchup_row := HBoxContainer.new()
	matchup_row.anchor_left = 0.15
	matchup_row.anchor_right = 0.85
	matchup_row.anchor_top = 0.785
	matchup_row.anchor_bottom = 0.935
	matchup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	matchup_row.add_theme_constant_override("separation", 2 if compact else 6)
	matchup_row.add_child(team_logo_rect(ensure_club_logo_id(), 17 if compact else 22, club_display_name()))
	matchup_row.add_child(fit_label(club_display_name(), 6 if compact else 8, TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT))
	matchup_row.add_child(plain_label("VS", 8 if compact else 11, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var rival_id := str(rival.get("team_id", rival.get("id", "")))
	var rival_name := str(rival.get("name", "待定對手"))
	matchup_row.add_child(team_logo_rect(rival_id, 17 if compact else 22, rival_name))
	matchup_row.add_child(fit_label(rival_name, 6 if compact else 8, TEXT, true))
	shell.add_child(matchup_row)
	return shell

func show_dashboard_more_menu() -> void:
	var existing := get_node_or_null("DashboardMoreMenu")
	if existing != null:
		existing.queue_free()
		return
	var panel := PanelContainer.new()
	panel.name = "DashboardMoreMenu"
	panel.anchor_left = 0.72
	panel.anchor_right = 0.985
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.91
	panel.add_theme_stylebox_override("panel", panel_style(Color("07101bf4"), GOLD, 12, 1))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(padded(box, 9))
	var head := HBoxContainer.new()
	head.add_child(fit_label("更多", 16, GOLD, true))
	head.add_child(action_button("×", Color("263443"), func(): show_dashboard_more_menu(), Vector2(38, 34)))
	box.add_child(head)
	for entry in [
		["遊戲設定", show_settings_hub],
		["遊戲指南", show_game_guide],
		["新聞中心", show_news_center],
		["存檔管理", show_save_slots],
		["所有功能", show_more_hub],
	]:
		var destination: Callable = entry[1]
		box.add_child(action_button(str(entry[0]), Color("172536e8"), func():
			clear_return_stack()
			open_sub(show_dashboard, destination)
		, Vector2(0, 34 if compact_phone() else 40)))

func build_dashboard_screen(opponent: Dictionary) -> void:
	match_play_id += 1
	clear_screen()
	current_stage = 3
	var compact := compact_phone()
	var bg := TextureRect.new()
	bg.name = "DashboardClubhouseArt"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = locker_room_tex() if home_environment_mode == "locker" else load_png_tex("res://assets/art/lobby/home_clubhouse_v2.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color("02050a26")
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := screen_safe_pad()
	safe.add_theme_constant_override("margin_left", pad.x)
	safe.add_theme_constant_override("margin_right", pad.z)
	safe.add_theme_constant_override("margin_top", pad.y)
	safe.add_theme_constant_override("margin_bottom", pad.w)
	safe.add_to_group("screen_safe_margins")
	add_child(safe)
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(stage)

	var header := PanelContainer.new()
	header.name = "DashboardClubHeader"
	header.anchor_left = 0.01
	header.anchor_right = 0.32
	header.anchor_top = 0.015
	header.anchor_bottom = 0.015
	header.offset_bottom = 46 if compact else 58
	header.add_theme_stylebox_override("panel", invisible_style())
	stage.add_child(header)
	header.add_child(dashboard_skin("res://assets/ui/home/club_header_skin_trim_v1.png"))
	# Use explicit, non-overlapping regions inside the decorative header. HBox
	# minimum sizes previously pushed the crest into the title on narrow devices.
	var header_content := Control.new()
	header_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_content)
	var club_mark := club_logo_button(24 if compact else 34, show_club_logo_picker)
	club_mark.position = Vector2(7 if compact else 10, 10 if compact else 11)
	club_mark.size = Vector2(24 if compact else 34, 24 if compact else 34)
	club_mark.mouse_filter = Control.MOUSE_FILTER_STOP
	header_content.add_child(club_mark)
	var club_title := fit_label(club_display_name(), 7 if compact else 13, TEXT, true)
	club_title.tooltip_text = club_display_name()
	club_title.anchor_right = 1.0
	club_title.offset_left = 48 if compact else 64
	club_title.offset_right = -10
	club_title.offset_top = 2 if compact else 3
	club_title.offset_bottom = 20 if compact else 27
	header_content.add_child(club_title)
	var club_record := fit_label("%s · %d勝 %d敗" % [current_league, season_wins, season_losses], 5 if compact else 8, GOLD, true)
	club_record.anchor_right = 1.0
	club_record.offset_left = 48 if compact else 64
	club_record.offset_right = -10
	club_record.offset_top = 25 if compact else 30
	club_record.offset_bottom = 43 if compact else 54
	header_content.add_child(club_record)
	var resource_row := HBoxContainer.new()
	resource_row.name = "DashboardResources"
	resource_row.anchor_left = 0.33
	resource_row.anchor_right = 0.99
	resource_row.anchor_top = 0.02
	resource_row.anchor_bottom = 0.02
	resource_row.offset_bottom = 44 if compact else 50
	resource_row.alignment = BoxContainer.ALIGNMENT_END
	resource_row.add_theme_constant_override("separation", 5 if compact else 8)
	stage.add_child(resource_row)
	resource_row.add_child(home_header_resource("黃金", str(gold), "res://assets/ui/hud/gold_coin.png", show_store_hub))
	resource_row.add_child(home_header_resource("球探點", str(scout_points), "res://assets/ui/hud/scout.png", show_gacha_market))
	resource_row.add_child(home_header_resource("資金", resource_display_number(budget_million, "萬"), "res://assets/ui/hud/budget.png", show_finance_sheet))
	var salary_space_text := "%s/%s萬" % [resource_display_number(roster_salary()), resource_display_number(salary_cap)]
	resource_row.add_child(home_header_resource("薪資空間", salary_space_text, "res://assets/ui/hud/budget.png", show_salary_sheet))
	var menu := action_button("☰", Color("111722ee"), show_dashboard_more_menu, Vector2(40 if compact else 54, 40 if compact else 46))
	menu.add_theme_font_size_override("font_size", 18 if compact else 25)
	menu.add_theme_stylebox_override("normal", panel_style(Color("10151ddd"), Color("90794388"), 8, 1))
	menu.tooltip_text = "更多：設定、指南、新聞與存檔"
	resource_row.add_child(menu)

	var schedule := home_schedule_carousel(opponent)
	schedule.anchor_left = 0.66
	schedule.anchor_right = 0.985
	schedule.anchor_top = 0.16
	schedule.anchor_bottom = 0.485
	stage.add_child(schedule)

	stage.add_child(dashboard_scene_shortcut("我的球館", func(): set_home_environment_mode("arena"), 0.025, 0.145, 0.16))
	stage.add_child(dashboard_scene_shortcut("更衣室", func(): set_home_environment_mode("locker"), 0.15, 0.27, 0.16))

	var task := home_task_panel()
	task.anchor_left = 0.73 if not compact else 0.70
	task.anchor_right = 0.98
	task.anchor_top = 0.53 if not compact else 0.54
	task.anchor_bottom = task.anchor_top
	task.offset_bottom = 112 if not compact else 66
	stage.add_child(task)

	var dock := bottom_navigation()
	dock.name = "BottomNavigation"
	dock.anchor_left = 0.015
	dock.anchor_right = 0.52
	dock.anchor_top = 0.865
	dock.anchor_bottom = 0.975
	dock.custom_minimum_size = Vector2.ZERO
	stage.add_child(dock)

	var start := action_button("", Color("00000000"), func(): show_match_prep(), Vector2.ZERO)
	start.name = "HomeStartMatch"
	start.anchor_left = 0.75 if not compact else 0.78
	start.anchor_right = 0.985
	start.anchor_top = 0.82
	start.anchor_bottom = 0.975
	start.add_theme_stylebox_override("normal", invisible_style())
	start.add_theme_stylebox_override("hover", panel_style(Color("ffffff10"), Color("fff0bd"), 12, 2))
	start.add_theme_stylebox_override("pressed", panel_style(Color("ffffff18"), GOLD, 12, 2))
	start.add_child(dashboard_skin("res://assets/ui/home/start_button_skin_trim_v1.png"))
	var start_ball := TextureRect.new()
	start_ball.texture = load_png_tex("res://assets/ui/hud/start_basketball_gold_v2.png")
	start_ball.anchor_left = 0.035
	start_ball.anchor_right = 0.205
	start_ball.anchor_top = 0.18
	start_ball.anchor_bottom = 0.82
	start_ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	start_ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	start_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start.add_child(start_ball)
	var start_text := plain_label("開始比賽", 17 if compact else 28, Color("fff6d8"), true, HORIZONTAL_ALIGNMENT_CENTER)
	start_text.anchor_left = 0.27
	start_text.anchor_right = 0.94
	start_text.anchor_top = 0.08
	start_text.anchor_bottom = 0.92
	start_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start.add_child(start_text)
	stage.add_child(start)
	modulate.a = 1.0

func home_scene_button(caption: String, icon_path: String, action: Callable, selected := false) -> Button:
	var button := action_button(caption, Color("101923e8"), action, Vector2(126 if is_handheld() else 142, 44))
	button.set_meta("button_role", "primary" if selected else "navigation")
	button.add_theme_font_size_override("font_size", 14 if is_handheld() else 15)
	button.add_theme_stylebox_override("normal", panel_style(Color("0a111be8"), GOLD if selected else Color("8b7540"), 10, 2 if selected else 1))
	button.add_theme_stylebox_override("hover", panel_style(Color("182230f2"), GOLD, 10, 2))
	button.icon = load_png_tex(icon_path)
	button.add_theme_constant_override("icon_max_width", 22)
	button.expand_icon = true
	return button

func home_task_panel() -> Control:
	var panel := Control.new()
	panel.name = "HomeDailyTask"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size.y = 62 if compact_phone() else 78
	panel.add_child(dashboard_skin("res://assets/ui/home/task_panel_skin_trim_v1.png"))
	var box := VBoxContainer.new()
	box.anchor_left = 0.06
	box.anchor_right = 0.72
	box.anchor_top = 0.10
	box.anchor_bottom = 0.90
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	box.add_child(kicker_label("今日任務", 10 if compact_phone() else 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var task_text := "完成一場比賽"
	var progress := "1/1" if mission_alert else "0/1"
	var row := HBoxContainer.new()
	row.add_child(fit_label(task_text, 10 if compact_phone() else 12, TEXT, true))
	row.add_child(plain_label(progress, 10 if compact_phone() else 12, GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT))
	box.add_child(row)
	var reward := hud_icon("res://assets/ui/hud/gold_coin.png", 21 if compact_phone() else 38)
	reward.anchor_left = 0.81
	reward.anchor_right = 0.92
	reward.anchor_top = 0.20
	reward.anchor_bottom = 0.60
	panel.add_child(reward)
	var reward_count := plain_label("×50", 6 if compact_phone() else 9, Color("fff0b0"), true, HORIZONTAL_ALIGNMENT_CENTER)
	reward_count.anchor_left = 0.80
	reward_count.anchor_right = 0.93
	reward_count.anchor_top = 0.57
	reward_count.anchor_bottom = 0.72
	reward_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(reward_count)
	# The reference lobby presents this as one clean mission card.  Keep the
	# entire card tappable without adding a bulky nested button.
	var hit := action_button("", Color("1b304200"), func(): jump_shortcut(show_daily_tasks), Vector2.ZERO)
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.tooltip_text = "查看今日任務"
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", panel_style(Color("ffffff0c"), GOLD, 13, 1))
	hit.add_theme_stylebox_override("pressed", panel_style(Color("ffffff16"), GOLD, 13, 1))
	panel.add_child(hit)
	return panel

func home_match_panel(opponent: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "HomeNextMatch"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("08111dec"), Color("d9b65699"), 14, 1))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	panel.add_child(padded(box, 10))
	box.add_child(kicker_label("下一場 · %s" % fixture_label(), 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var marks := HBoxContainer.new()
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	marks.add_theme_constant_override("separation", 8)
	marks.add_child(home_banner_mark(34 if is_handheld() else 42))
	marks.add_child(plain_label("VS", 14, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	marks.add_child(team_logo_rect(str(opponent.get("team_id", "")), 38 if is_handheld() else 46, str(opponent.get("name", "對手"))))
	box.add_child(marks)
	box.add_child(fit_label(str(opponent.get("name", "對手")), 16, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	return panel

func set_home_environment_mode(mode: String) -> void:
	home_environment_mode = mode
	show_dashboard()

func home_lobby_scene(opponent: Dictionary) -> Control:
	var scene := PanelContainer.new()
	scene.name = "HomeEnvironment"
	scene.custom_minimum_size = Vector2(0, 214 if compact_phone() else 390)
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.clip_contents = true
	scene.add_theme_stylebox_override("panel", invisible_style())
	var stage := Control.new()
	stage.custom_minimum_size = scene.custom_minimum_size
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.add_child(stage)
	var modes := HBoxContainer.new()
	modes.position = Vector2(12, 12)
	modes.size = Vector2(290, 44)
	modes.add_theme_constant_override("separation", 7)
	stage.add_child(modes)
	modes.add_child(home_scene_button("我的球館", "res://assets/ui/icons/nav_home.png", func(): set_home_environment_mode("arena"), home_environment_mode == "arena"))
	modes.add_child(home_scene_button("更衣室", "res://assets/ui/icons/nav_roster.png", func(): set_home_environment_mode("locker"), home_environment_mode == "locker"))

	var right := VBoxContainer.new()
	right.anchor_left = 0.70
	right.anchor_top = 0.03 if compact_phone() else 0.30
	right.anchor_right = 0.99
	right.anchor_bottom = right.anchor_top
	right.offset_bottom = 122 if compact_phone() else 150
	right.add_theme_constant_override("separation", 10)
	stage.add_child(right)
	right.add_child(home_task_panel())
	var start := gold_action_button("開始比賽", func(): show_match_prep(), Vector2(0, 48 if compact_phone() else 60))
	start.name = "HomeStartMatch"
	start.add_theme_font_size_override("font_size", 20 if is_handheld() else 26)
	right.add_child(start)
	return scene

func maybe_show_tutorial() -> void:
	if tutorial_seen or season_games > 0:
		return
	if OS.get_environment("TB_SHOT") == "1" or OS.get_environment("TB_PLAYTEST") == "1" or OS.get_environment("TB_MACPLAY") == "1":
		tutorial_seen = true
		return
	if has_node("TutorialVeil"):
		return
	show_tutorial_overlay()

func onboarding_next_step_panel() -> Control:
	# A single, persistent next action keeps the first session understandable
	# without hiding the full dashboard for returning players.
	var panel := PanelContainer.new()
	panel.name = "OnboardingNextStep"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("10283aee"), CYAN.darkened(0.2), 12, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(padded(row, 8 if is_handheld() else 10))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 1)
	row.add_child(words)
	var title := "下一步"
	var body := ""
	var action_text := "前往"
	var action: Callable = show_match_prep
	if season_games <= 0:
		title = "新手目標 · 完成第一場比賽"
		body = "先發 5 人與替補已自動補齊；先查看賽前陣容，再按開始比賽。"
		action_text = "查看賽前"
		action = show_match_prep
	elif team_players.size() < minimum_roster_to_play():
		title = "下一步 · 補足可比賽名單"
		body = "至少保留 %d 名球員才能開打，目前 %d 人。" % [minimum_roster_to_play(), team_players.size()]
		action_text = "前往編隊"
		action = func(): show_roster(true)
	elif match_rewards_pending:
		title = "下一步 · 查看比賽結算"
		body = "上一場比賽已完成，先查看比分、技能與資源變化。"
		action_text = "查看結算"
		action = show_post_match
	else:
		title = "下一步 · 準備下一場"
		body = "%s。可先調整戰術或查看對手陣容。" % next_fixture_line()
		action_text = "查看賽前"
		action = show_match_prep
	words.add_child(kicker_label(title, 12 if is_handheld() else 13, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	words.add_child(wrap_label(body, 12 if is_handheld() else 13, TEXT, true))
	var button := action_button(action_text, ORANGE, action, Vector2(102 if is_handheld() else 124, 38 if is_handheld() else 42))
	button.add_theme_font_size_override("font_size", 13 if is_handheld() else 14)
	row.add_child(button)
	return panel

func show_tutorial_overlay() -> void:
	var veil := ColorRect.new()
	veil.name = "TutorialVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.03, 0.05, 0.62)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(400 if compact_phone() else 460, 0)
	sheet.add_theme_stylebox_override("panel", glass_style(18))
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	sheet.add_child(padded(box, 16))
	box.add_child(label("怎麼玩", 22, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(wrap_label("大廳按「開打」打下一場。", 14, TEXT, true))
	box.add_child(wrap_label("底下「編隊」點兩名球員互換先發。", 14, TEXT, true))
	box.add_child(wrap_label("「更多」最上排球探、市場找人。", 14, TEXT, true))
	box.add_child(wrap_label("頂列常駐資金、黃金、薪資／上限、球探點；點數值可看明細。", 14, TEXT, true))
	box.add_child(action_button("知道了", ORANGE, func():
		tutorial_seen = true
		save_game()
		if is_instance_valid(veil):
			veil.queue_free()
	, Vector2(0, 46)))

func home_last_game_line() -> String:
	if not last_match_played:
		return "還沒打過，第一場從這裡開打"
	var won := int(last_score[0]) > int(last_score[1])
	var streak := ""
	if won and win_streak > 1:
		streak = " · 連勝 %d" % win_streak
	return "上一場 %d－%d %s · MVP %s%s" % [int(last_score[0]), int(last_score[1]), "勝" if won else "負", last_mvp, streak]

func match_banner(opponent: Dictionary) -> Control:
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shell.clip_contents = false
	shell.add_theme_stylebox_override("panel", invisible_style())
	var banner_art := load_png_tex("res://assets/ui/hud/banner_panel.png")
	if banner_art != null:
		var plate := TextureRect.new()
		plate.texture = banner_art
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		plate.custom_minimum_size = Vector2.ZERO
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plate.modulate = Color(1, 1, 1, 0.40)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(padded(row, 6))
	var marks := HBoxContainer.new()
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	marks.add_theme_constant_override("separation", 6)
	row.add_child(marks)
	marks.add_child(home_banner_mark(40))
	marks.add_child(team_logo_rect(str(opponent.get("team_id", "")), 46, str(opponent.get("name", "球"))))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	copy.add_child(kicker_label("下一場  ·  %s" % fixture_label(), 10, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	copy.add_child(polish_title(fit_label("VS  %s" % str(opponent.get("name", "對手")), 20, TEXT, true)))
	if over_salary_cap():
		copy.add_child(fit_label("已超薪資帽，先去編隊才能開打", 11, RED, true))
	else:
		var last_line := home_last_game_line()
		var miss := lineup_mismatch_line()
		if not miss.is_empty() and not is_handheld():
			copy.add_child(fit_label(miss, 11, RED, true))
		copy.add_child(fit_label(last_line, 11, MUTED, true))
	if not over_salary_cap() and not combo_state().is_empty():
		row.add_child(combo_status_chip())
	if over_salary_cap():
		row.add_child(action_button("去編隊", RED, func(): show_roster(true), Vector2(108, 42)))
	else:
		row.add_child(play_start_button(func(): show_match_prep(), Vector2(128, 44)))
	return shell

func compact_menu_tile(title: String, subtitle: String, accent: Color, action: Callable, _icon_id: String) -> Control:
	var hit := action_button("", accent.darkened(0.72), action, Vector2(0, 80))
	hit.add_theme_stylebox_override("normal", panel_style(Color("0b1b2aee"), accent.darkened(0.45), 12, 1))
	hit.tooltip_text = subtitle
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.add_child(row)
	var title_lab := fit_label(title, 22, accent, true)
	title_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_lab)
	return hit

func phone_roster_board(swap_mode := false) -> Control:
	var board := VBoxContainer.new()
	board.name = "PhoneRosterBoard"
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 0)
	var starters := VBoxContainer.new()
	starters.add_theme_constant_override("separation", 2)
	starters.add_child(fit_label("先發 · 後場 3 人／前場 2 人", 14, GOLD, true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	starters.add_child(row)
	for i in mini(5, team_players.size()):
		row.add_child(lobby_player_card(team_players[i], true, i, swap_mode, 104))
	board.add_child(starters)
	var bench := VBoxContainer.new()
	bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bench.add_theme_constant_override("separation", 2)
	bench.add_child(fit_label("替補 %d 人" % maxi(0, team_players.size() - 5), 14, CYAN, true))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 4)
	bench.add_child(cards)
	for i in range(5, mini(team_players.size(), gameday_limit())):
		cards.add_child(lobby_player_card(team_players[i], false, i, swap_mode, 104))
	if cards.get_child_count() == 0:
		cards.add_child(fit_label("到市場補強替補", 14, MUTED))
	board.add_child(bench)
	return board

func route_nested_vertical_drag(inner: ScrollContainer, event: InputEvent) -> void:
	if not (event is InputEventScreenDrag):
		return
	var drag := event as InputEventScreenDrag
	if absf(drag.relative.y) <= absf(drag.relative.x):
		return
	var ancestor := inner.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor is ScrollContainer:
			var outer := ancestor as ScrollContainer
			outer.scroll_vertical = clampi(outer.scroll_vertical - roundi(drag.relative.y), 0, maxi(0, roundi(outer.get_v_scroll_bar().max_value - outer.get_v_scroll_bar().page)))
			inner.accept_event()
			return
		ancestor = ancestor.get_parent()

func restore_phone_bench_scroll(target: WeakRef, offset: int) -> void:
	await get_tree().process_frame
	var scroll = target.get_ref()
	if is_instance_valid(scroll):
		scroll.set_deferred("scroll_horizontal", offset)

func lobby_roster_board(swap_mode := false) -> Control:
	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL if not swap_mode else Control.SIZE_SHRINK_BEGIN
	board.clip_contents = false
	board.add_theme_stylebox_override("panel", panel_style(Color(0.04, 0.06, 0.09, 0.52), Color(0.96, 0.78, 0.32, 0.18), 16, 1))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	board.add_child(padded(box, 6))
	var starter_title := "先發 · 點兩張卡互換 · 位置不符 -5 OVR" if swap_mode else "先發 · 點卡看資料"
	var head := HBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	head.visible = not is_handheld()
	var title_lab := kicker_label(starter_title, 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	if not swap_mode and active_menu == "dashboard":
		var edit_btn := action_button("編輯陣容", GOLD, func(): show_roster(true), Vector2(108, 32))
		edit_btn.add_theme_font_size_override("font_size", 22 if is_handheld() else 13)
		head.add_child(edit_btn)
	if swap_mode and not roster_filters_clear():
		var hit_n := 0
		for i in team_players.size():
			if roster_matches_filter(team_players[i]):
				hit_n += 1
		box.add_child(kicker_label("篩選結果 %d 人 · 只有符合的卡片" % hit_n, 11, CYAN, HORIZONTAL_ALIGNMENT_LEFT))
		box.add_child(lobby_card_flow(0, "沒有符合篩選的人，改條件或按全部。"))
		return board
	box.add_child(lobby_starter_groups(swap_mode, 1.0))
	var bench_n := maxi(0, team_players.size() - 5)
	var shown_n := 0
	for i in range(5, team_players.size()):
		if roster_matches_filter(team_players[i]):
			shown_n += 1
	var bench_title := "替補 %d 人" % bench_n
	if swap_mode and bench_n > 0:
		if roster_filters_clear():
			bench_title = "其餘名單 %d 人 · 點兩張卡互換，人多就用篩選" % bench_n
		else:
			bench_title = "篩選結果 %d／%d 人 · 點兩張互換" % [shown_n, bench_n]
	elif bench_n > 0:
		bench_title = "替補 %d 人" % bench_n
	box.add_child(kicker_label(bench_title, 11, CYAN, HORIZONTAL_ALIGNMENT_LEFT))
	if swap_mode:
		box.add_child(lobby_card_flow(5, "還沒有替補。球探挖人或市場買人。"))
	else:
		var bench := lobby_card_row(5, gameday_limit(), false, swap_mode, "還沒有替補。點卡片去編隊。", 1.0)
		bench.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(bench)
	return board

func lobby_starter_groups(swap_mode: bool, stretch: float) -> Control:
	var wrap := HBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL if not swap_mode else Control.SIZE_SHRINK_BEGIN
	wrap.size_flags_stretch_ratio = stretch
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 8)
	wrap.add_child(lobby_labeled_card_group("後場", 0, 3, true, swap_mode, 0.0))
	wrap.add_child(lobby_labeled_card_group("前場", 3, 5, true, swap_mode, 0.0))
	wrap.add_child(lineup_side_hint())
	return wrap

func lobby_labeled_card_group(title: String, from_index: int, to_index: int, starter: bool, swap_mode: bool, _stretch: float) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL if not swap_mode else Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 2)
	var accent := CYAN if title == "後場" else ORANGE
	col.add_child(kicker_label(title, 10, accent, HORIZONTAL_ALIGNMENT_CENTER))
	var row := lobby_card_row(from_index, to_index, starter, swap_mode, "空缺", 1.0)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	return col

func lobby_card_row(from_index: int, to_index: int, starter: bool, swap_mode: bool, empty_text: String, stretch: float) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.size_flags_stretch_ratio = stretch
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var has_any := false
	for i in range(from_index, to_index):
		if i < team_players.size():
			has_any = true
			break
	if not has_any:
		var empty := VBoxContainer.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.add_theme_constant_override("separation", 6)
		var empty_art := load_png_tex("res://assets/ui/hud/empty_bench.png")
		if empty_art != null and not starter:
			var shot := TextureRect.new()
			shot.texture = empty_art
			shot.custom_minimum_size = Vector2(180, 72)
			shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			shot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty.add_child(shot)
		empty.add_child(fit_label(empty_text, 13, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(empty)
		return row
	var card_w := lobby_card_width(swap_mode)
	for i in range(from_index, to_index):
		if i >= team_players.size():
			continue
		var card := lobby_player_card(team_players[i], starter, i, swap_mode, card_w)
		row.add_child(card)
	return row

func lobby_card_flow(from_index: int, empty_text: String) -> Control:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var card_w := lobby_card_width(true)
	var shown := 0
	for i in range(from_index, team_players.size()):
		if not roster_matches_filter(team_players[i]):
			continue
		flow.add_child(lobby_player_card(team_players[i], false, i, true, card_w))
		shown += 1
	if shown > 0:
		return flow
	var empty := VBoxContainer.new()
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty.alignment = BoxContainer.ALIGNMENT_CENTER
	empty.add_child(fit_label(empty_text if roster_filters_clear() else "沒有符合篩選的人，改條件或按全部。", 13, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	return empty

func lobby_card_width(swap_mode := false) -> int:
	if is_handheld():
		return 112
	if not swap_mode and active_menu == "dashboard":
		return 83
	return 76

func card_frame_layer(frame_tex: Texture2D, tint := Color.WHITE) -> TextureRect:
	var frame_art := TextureRect.new()
	frame_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_art.texture = frame_tex
	frame_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_art.stretch_mode = TextureRect.STRETCH_SCALE
	frame_art.custom_minimum_size = Vector2.ZERO
	frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_art.modulate = tint
	return frame_art

func card_bust_layer(tex: Texture2D) -> TextureRect:
	var photo := TextureRect.new()
	photo.anchor_left = 0.11
	photo.anchor_right = 0.89
	photo.anchor_top = 0.06
	photo.anchor_bottom = 0.78
	photo.offset_left = 0.0
	photo.offset_right = 0.0
	photo.offset_top = 0.0
	photo.offset_bottom = 0.0
	photo.texture = tex
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.custom_minimum_size = Vector2.ZERO
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return photo

func player_origin_name_row(player: Dictionary, name_px := 10) -> Control:
	var who := str(player.get("name", "球員"))
	var line := who
	if not is_locked_prize(player):
		var origin_title := veteran_prime_team_name(player)
		if origin_title.is_empty():
			origin_title = team_short_name(origin_id(player))
		if not origin_title.is_empty():
			line = "%s %s" % [origin_title, who]
	var name_mark := polish_title(plain_label(line, name_px, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	name_mark.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_mark.clip_text = true
	name_mark.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_mark.custom_minimum_size = Vector2(0, name_px + 2)
	return name_mark

func card_plate_label(text_value: String, font_px: int, color: Color, _display := false) -> Label:
	var lab := Label.new()
	lab.add_theme_font_override("font", FONT_BOLD)
	lab.add_theme_font_size_override("font_size", font_px)
	lab.add_theme_color_override("font_color", color)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.clip_text = true
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.custom_minimum_size = Vector2(0, font_px + 1)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_constant_override("outline_size", 2)
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 0.85))
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	lab.add_theme_constant_override("shadow_offset_x", 0)
	lab.add_theme_constant_override("shadow_offset_y", 0)
	lab.add_theme_constant_override("shadow_outline_size", 0)
	lab.text = text_value
	lab.reset_size()
	return lab

func lobby_player_card(player: Dictionary, _starter: bool, index := -1, swap_mode := false, card_w := 96, on_press := Callable(), card_h_override := -1, footer_text := "") -> Control:
	# The compact mobile layout uses the same artwork and typography hierarchy at
	# 75% of the former card footprint across home, roster, scout and markets.
	card_w = maxi(40, roundi(float(card_w) * 0.75))
	if card_h_override > 0:
		card_h_override = maxi(58, roundi(float(card_h_override) * 0.75))
	var selected := (swap_mode and index == selected_foundation) or (roster_batch_mode and roster_batch_selected.has(str(index)))
	var swapping := swap_mode and index == swap_pick
	var hit := Button.new()
	hit.text = ""
	hit.clip_contents = true
	hit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hit.set_meta("player_card", true)
	var card_h := card_h_override if card_h_override > 0 else int(round(float(card_w) / 0.68))
	hit.custom_minimum_size = Vector2(card_w, card_h)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.flat = true
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", invisible_style())
	hit.add_theme_stylebox_override("pressed", invisible_style())
	hit.add_theme_stylebox_override("focus", invisible_style())
	if swapping:
		hit.modulate = Color(1.16, 0.94, 0.74)
	elif selected:
		hit.modulate = Color(1.08, 1.04, 0.84)
	# Printed origin remains the original team for normal cards.  Veteran cards
	# print the club from their prime years; combo flexibility only affects play.
	var printed_origin := str(player.get("origin_team_id", ""))
	if printed_origin.is_empty():
		printed_origin = team_id_from_display_name(str(player.get("team", "")))
	if printed_origin.is_empty():
		printed_origin = catalog_origin_id_for_player(player)
	var printed_logo: Texture2D = null
	var printed_mark_origin := printed_origin
	var origin_title := "" if player_tier_key(player) == "diamond" else veteran_prime_team_name(player)
	if is_veteran_player(player):
		printed_logo = veteran_prime_logo(player)
		var prime_id := veteran_prime_team_id(player)
		if not prime_id.is_empty():
			printed_mark_origin = prime_id
	if origin_title.is_empty() and player_tier_key(player) != "diamond":
		origin_title = team_display_name(printed_origin)
	if bool(player.get("draft_2026", false)):
		origin_title = str(player.get("draft_school", "2026 選秀新人"))
	if origin_title.is_empty() and player_tier_key(player) != "diamond":
		origin_title = "原球隊資料待補"
	var visual := PlayerCardVisual.new()
	visual.size = Vector2(card_w, card_h)
	var show_team_mark := player_tier_key(player) != "diamond"
	visual.configure({
		"portrait": blended_card_portrait(player),
		"court": card_court_for(player),
		"court_tint": card_court_tint(player),
		"frame": card_frame_for(player_tier_key(player)),
		"frame_tint": card_frame_tint(player_tier_key(player)),
		"tier": player_tier_key(player),
		"logo": printed_logo if (show_team_mark and printed_logo != null) else (team_logo_tex(printed_origin) if show_team_mark else null),
		"logo_mark": team_mark_letter(printed_mark_origin) if show_team_mark else "",
		"origin": origin_title,
		"position": "—" if position_data_missing(player) else "/".join(player_pos_list(player)),
		"ovr": effective_ovr(player, index),
		"identity": "外籍生" if is_foreign_student(player) else ("外援" if is_foreigner(player) else ""),
		"player_name": str(player.get("name", "球員")),
		"salary": "$%d萬" % int(float(player.get("salary_million", published_salary(player)))),
		"training_sessions": int(player.get("training_sessions", 0)),
	}, {"bold": FONT_BOLD, "kicker": FONT_KICKER_FILE, "number": FONT_NUMBER_FILE})
	hit.add_child(visual)
	var footers: Array[String] = []
	if not footer_text.is_empty():
		footers.append(footer_text)
		hit.tooltip_text = footer_text
	if roster_batch_mode and swap_mode:
		footers.append("已選" if selected else "點選")
	elif swap_mode:
		footers.append("互換中" if swapping else ("點他互換" if selected else "替換"))
	elif index >= 12:
		footers.append("未登錄")
	# Action/status captions have their own space; never cover the artwork/name/salary.
	# Labels keep a 24-unit minimum line height with the shared theme, also on desktop.
	var footer_height := 24
	for i in footers.size():
		var caption := card_plate_label(footers[i], 16 if is_handheld() else 9, ORANGE_2 if swap_mode else MUTED)
		caption.name = "CardFooter%d" % i
		caption.position = Vector2(0, card_h + i * footer_height)
		caption.size = Vector2(card_w, footer_height)
		hit.add_child(caption)
	hit.custom_minimum_size.y = card_h + footers.size() * footer_height
	hit.pressed.connect(func():
		play_sfx("tap")
		if roster_batch_mode and swap_mode and index >= 0:
			toggle_roster_batch(index)
		elif on_press.is_valid():
			on_press.call()
		elif swap_mode and index >= 0:
			tap_roster_slot(index)
		else:
			show_owned_player(index)
	)
	bind_press_juice(hit, hit)
	return hit

func tap_roster_slot(index: int) -> void:
	if index < 0 or index >= team_players.size():
		return
	selected_foundation = index
	if swap_pick < 0 or swap_pick == index:
		swap_pick = -1 if swap_pick == index else index
		show_roster()
		return
	if swap_pick >= team_players.size():
		swap_pick = -1
		show_roster()
		return
	var tmp: Dictionary = team_players[swap_pick]
	team_players[swap_pick] = team_players[index]
	team_players[index] = tmp
	swap_pick = -1
	save_game()
	show_roster()
	var miss := lineup_mismatch_line()
	if not miss.is_empty():
		flash_notice(miss)

func toggle_roster_batch(index: int) -> void:
	if index < 0 or index >= team_players.size():
		return
	var key := str(index)
	if roster_batch_selected.has(key):
		roster_batch_selected.erase(key)
	else:
		roster_batch_selected[key] = true
	show_roster(true)

func clear_roster_batch() -> void:
	roster_batch_selected.clear()
	show_roster(true)

func apply_roster_batch_destination(destination: String) -> void:
	var selected: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for i in team_players.size():
		if roster_batch_selected.has(str(i)):
			selected.append(team_players[i])
		else:
			remaining.append(team_players[i])
	if selected.is_empty():
		flash_notice("請先點選要批次調整的球員")
		return
	if destination == "starter" and selected.size() > 5:
		flash_notice("正選最多 5 人，目前選了 %d 人" % selected.size())
		return
	var preview := "設為正選" if destination == "starter" else "設為替補"
	var names := PackedStringArray()
	for player in selected:
		names.append(str(player.get("name", "球員")))
	show_guide_sheet("確認批次調整", "%s：%s\n\n套用後會重新排列正選／替補，不會刪除球員。" % [preview, "、".join(names)], GOLD, "確認套用", func():
		close_guide_modal()
		var reordered: Array[Dictionary] = []
		if destination == "starter":
			reordered.append_array(selected)
			reordered.append_array(remaining)
		else:
			reordered.append_array(remaining)
			reordered.append_array(selected)
		team_players.assign(reordered)
		roster_batch_selected.clear()
		roster_batch_mode = false
		swap_pick = -1
		selected_foundation = 0
		save_game()
		show_roster(true)
		flash_notice("批次調整完成：%s" % preview)
	)

func optimize_current_lineup() -> void:
	if team_players.size() < 5:
		flash_notice("至少需要 5 名球員才能自動排先發")
		return
	var slots := ["PG", "SG", "SF", "PF", "C"]
	var remaining: Array[Dictionary] = []
	for raw in team_players:
		if raw is Dictionary:
			remaining.append(raw)
	var starters: Array[Dictionary] = []
	for slot in slots:
		var best_index := -1
		var best_score := -9999
		for i in remaining.size():
			var candidate: Dictionary = remaining[i]
			if not player_fits_slot(candidate, slot):
				continue
			var score := int(candidate.get("ovr", 70))
			if normalize_pos_code(str(candidate.get("pos", candidate.get("position", "")))) == slot:
				score += 3
			if score > best_score:
				best_score = score
				best_index = i
		if best_index < 0:
			for i in remaining.size():
				var fallback: Dictionary = remaining[i]
				var fallback_score := int(fallback.get("ovr", 70))
				if fallback_score > best_score:
					best_score = fallback_score
					best_index = i
		if best_index >= 0:
			starters.append(remaining[best_index])
			remaining.remove_at(best_index)
	var reordered: Array[Dictionary] = []
	reordered.append_array(starters)
	remaining.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(a.get("ovr", 70)) > int(b.get("ovr", 70))
	)
	reordered.append_array(remaining)
	team_players.assign(reordered)
	swap_pick = -1
	selected_foundation = 0
	apply_combo_label()
	save_game()
	show_roster(true)
	flash_notice("已依位置適性與 OVR 排出最佳先發")

func entry_card(caption: String, icon_id: String, action: Callable) -> Control:
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	holder.add_theme_constant_override("separation", 4)
	var hit := Button.new()
	hit.text = ""
	hit.clip_contents = true
	hit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hit.custom_minimum_size = Vector2(0, 56 if compact_phone() else 72)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", panel_style(Color(0.05, 0.06, 0.09, 0.45), GOLD, 14, 2))
	hit.add_theme_stylebox_override("hover", panel_style(Color(0.08, 0.09, 0.12, 0.25), ORANGE, 14, 2))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(0.04, 0.05, 0.08, 0.55), TEXT, 14, 1))
	hit.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	bind_press_juice(hit, hit)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 8
	art.offset_top = 6
	art.offset_right = -8
	art.offset_bottom = -6
	art.texture = nav_icon_tex(icon_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.add_child(art)
	holder.add_child(hit)
	holder.add_child(plain_label(caption, 14, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	return holder

func hub_tile(title: String, subtitle: String, footnote: String, accent: Color, action: Callable, _art_player: Dictionary = {}, compact := false, icon_id := "", selected := false) -> Control:
	var art_tex := hub_art_tex(icon_id)
	if is_handheld() and active_menu == "more":
		return compact_menu_tile(title, subtitle, accent, action, icon_id)
	if art_tex != null:
		return hub_art_tile(title, subtitle, footnote, accent, action, art_tex, compact, selected)
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(0, 56 if compact else (88 if compact_phone() else 118))
	shell.clip_contents = true
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if selected:
		shell.add_theme_stylebox_override("panel", gold_select_style())
	else:
		shell.add_theme_stylebox_override("panel", glass_style(16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if compact else 10)
	shell.add_child(padded(row, 8 if compact else 10))
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(6 if selected else 4, 0)
	bar.color = GOLD if selected else accent
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1 if compact else 3)
	row.add_child(box)
	var title_color := Color("fff6d8") if selected else accent
	box.add_child(fit_label(title, 15 if compact else 18, title_color, true))
	if compact:
		box.add_child(fit_label(footnote if not footnote.is_empty() else subtitle, 11, Color("fff4cc") if selected else TEXT, true))
	else:
		box.add_child(fit_label(subtitle, 13, Color("fff8e8") if selected else TEXT, true))
		box.add_child(fit_label(footnote, 12, Color("ffe9a8") if selected else MUTED, false))
	var hit := hub_tile_hit(accent, selected, action)
	bind_press_juice(shell, hit)
	shell.add_child(hit)
	return shell

func hub_art_tile(title: String, subtitle: String, footnote: String, accent: Color, action: Callable, art_tex: Texture2D, compact: bool, selected: bool) -> Control:
	var tall := (80 if is_handheld() else 76) if compact else 118
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(0, tall)
	shell.clip_contents = true
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if selected:
		shell.add_theme_stylebox_override("panel", gold_select_style())
	else:
		shell.add_theme_stylebox_override("panel", panel_style(Color(0.04, 0.05, 0.08, 0.92), accent.darkened(0.2), 14, 1))
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(0, tall)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(inner)
	var plate := TextureRect.new()
	plate.texture = art_tex
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(plate)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(shade)
	var words := VBoxContainer.new()
	words.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	words.offset_left = 10
	words.offset_right = -10
	words.offset_top = -52
	words.offset_bottom = -8
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	inner.add_child(words)
	var title_color := Color("fff6d8") if selected else Color("fff8e8")
	words.add_child(fit_label(title, 16 if compact else 18, title_color, true, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := footnote if compact and not footnote.is_empty() else subtitle
	if not sub.is_empty():
		words.add_child(fit_label(sub, 11, GOLD if selected else TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	var hit := hub_tile_hit(accent, selected, action)
	inner.add_child(hit)
	bind_press_juice(shell, hit)
	return shell

func hub_tile_hit(accent: Color, selected: bool, action: Callable) -> Button:
	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.flat = true
	hit.add_theme_stylebox_override("normal", invisible_style())
	hit.add_theme_stylebox_override("hover", panel_style(Color(1, 1, 1, 0.10 if selected else 0.08), GOLD if selected else accent, 16, 0))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(1, 1, 1, 0.16), TEXT, 16, 0))
	hit.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	return hit

func show_result_hub() -> void:
	if last_match_played:
		show_post_match()
		return
	active_menu = "result"
	var content := begin_screen("結算", "打完才會留下比分與 MVP", 4)
	content.add_child(hub_tile("還沒開打", "先去賽前看今晚對手", "自動播四節 · 技能特寫", ORANGE, func(): show_match_prep(), {}))

func show_roster(edit_mode: Variant = null) -> void:
	active_menu = "roster"
	if typeof(edit_mode) == TYPE_BOOL:
		roster_editing = bool(edit_mode)
	if not roster_editing:
		swap_pick = -1
		roster_batch_mode = false
		roster_batch_selected.clear()
	apply_combo_label()
	ensure_bench()
	for i in team_players.size():
		if team_players[i] is Dictionary:
			team_players[i] = refresh_stored_player(team_players[i])
	ensure_photographed_starters()
	var hint := "點兩張卡互換。先點人再放保管箱或釋出。" if roster_editing else "點卡看資料與養成。要換人先按編輯陣容。"
	var content := begin_screen("編隊", hint, 4)
	var chips := HBoxContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("separation", 6)
	content.add_child(chips)
	chips.visible = not is_handheld() or roster_filters_visible
	chips.add_child(roster_count_pill("名單", "%d／%d" % [team_players.size(), roster_limit()], GOLD))
	chips.add_child(roster_count_pill("保管箱", str(card_inventory.size()), CYAN))
	chips.add_child(roster_count_pill("外援", "%d／%d" % [foreigner_count(), foreigner_limit()], ORANGE))
	chips.add_child(roster_count_pill("外籍生", "%d／%d" % [foreign_student_count(), foreign_student_limit()], PURPLE))
	if not is_handheld() or roster_filters_visible:
		content.add_child(roster_filter_bar())
	content.add_child(phone_roster_board(roster_editing) if is_handheld() and roster_filters_clear() else lobby_roster_board(roster_editing))
	if is_handheld() and not roster_filters_visible:
		content.move_child(chips, content.get_child_count() - 1)
	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	actions.add_theme_constant_override("separation", 8)
	if is_handheld():
		var filter_btn := action_button("收起篩選" if roster_filters_visible else "篩選／名單", Color("254e6b"), func():
			roster_filters_visible = not roster_filters_visible
			show_roster()
		)
		filter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(filter_btn)
	if roster_editing:
		var batch_btn := action_button("退出批次" if roster_batch_mode else "批次編輯", CYAN, func():
			roster_batch_mode = not roster_batch_mode
			roster_batch_selected.clear()
			show_roster(true)
		)
		batch_btn.name = "BatchRosterButton"
		batch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(batch_btn)
		if roster_batch_mode:
			var selected_count := roster_batch_selected.size()
			var starter_btn := gold_action_button("設為正選 (%d)" % selected_count, func(): apply_roster_batch_destination("starter"))
			starter_btn.name = "BatchSetStarterButton"
			starter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(starter_btn)
			var bench_btn := action_button("設為替補 (%d)" % selected_count, CYAN, func(): apply_roster_batch_destination("bench"))
			bench_btn.name = "BatchSetBenchButton"
			bench_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(bench_btn)
			var clear_batch_btn := action_button("清除選取", Color("254052"), func(): clear_roster_batch())
			clear_batch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(clear_batch_btn)
		var auto_btn := gold_action_button("一鍵最佳", func(): optimize_current_lineup())
		auto_btn.name = "AutoBestLineupButton"
		auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		auto_btn.tooltip_text = "依 PG／SG／SF／PF／C 適性與 OVR 自動安排先發，其他球員留在替補。"
		actions.add_child(auto_btn)
		var done_btn := gold_action_button("完成編輯", func(): show_roster(false))
		done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(done_btn)
	else:
		var edit_btn := gold_action_button("編輯陣容", func(): show_roster(true))
		edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(edit_btn)
	var tactic_btn := gold_action_button("戰術", func(): open_sub(show_roster, show_tactics))
	tactic_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(tactic_btn)
	if not roster_editing:
		var vault_btn := gold_action_button("保管箱", func(): show_card_vault())
		vault_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(vault_btn)
	if roster_editing:
		var pick_name := ""
		if selected_foundation >= 0 and selected_foundation < team_players.size():
			pick_name = str(team_players[selected_foundation].get("name", ""))
		var stash_txt := "放保管箱" if is_handheld() else ("放入保管箱 %s" % pick_name if not pick_name.is_empty() else "放入保管箱（先點人）")
		var stash_btn := gold_action_button(stash_txt, func():
			if selected_foundation < 0 or selected_foundation >= team_players.size():
				flash_notice("先點一名球員，再放入保管箱。")
				return
			move_roster_to_vault(selected_foundation)
		)
		stash_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stash_btn.tooltip_text = "鑽石卡也可放保管箱。箱內不算薪資帽。"
		actions.add_child(stash_btn)
		var release_txt := "釋出球員" if is_handheld() else ("釋出 %s" % pick_name if not pick_name.is_empty() else "釋出（先點人）")
		var release_btn := action_button(release_txt, Color("254e6b"), func():
			if selected_foundation < 0 or selected_foundation >= team_players.size():
				flash_notice("先點一名球員，再按釋出。")
				return
			release_roster_player(selected_foundation)
		, Vector2(0, 42))
		release_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		release_btn.tooltip_text = "永久刪除。鑽石卡不能釋出。至少留 7 人才能開打。"
		actions.add_child(release_btn)
	pin_above_dock(content, actions)

func pin_above_dock(content: Control, bar: Control) -> void:
	var scroll := content.get_parent()
	if not (scroll is ScrollContainer):
		content.add_child(bar)
		return
	var page := scroll.get_parent()
	if not (page is VBoxContainer):
		content.add_child(bar)
		return
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	var last := page.get_child(page.get_child_count() - 1)
	page.add_child(bar)
	if last is PanelContainer:
		page.move_child(bar, last.get_index())

func roster_filters_clear() -> bool:
	return roster_filter_pos.is_empty() and roster_filter_origin.is_empty() and roster_filter_ovr == 0

func roster_matches_filter(player: Dictionary) -> bool:
	if not roster_filter_pos.is_empty() and roster_filter_pos not in player_pos_list(player):
		return false
	if not roster_filter_origin.is_empty() and origin_id(player) != roster_filter_origin:
		return false
	var ovr := int(player.get("ovr", 70))
	if roster_filter_ovr > 0 and ovr < roster_filter_ovr:
		return false
	if roster_filter_ovr < 0 and ovr > absi(roster_filter_ovr):
		return false
	return true

func roster_origin_options() -> Array[String]:
	var seen: Dictionary = {}
	var ids: Array[String] = []
	for player in team_players:
		if not (player is Dictionary):
			continue
		var origin := origin_id(player)
		if origin.is_empty() or seen.has(origin):
			continue
		seen[origin] = true
		ids.append(origin)
	ids.sort_custom(func(a, b): return team_short_name(a) < team_short_name(b))
	return ids

func roster_filter_chip(title: String, active: bool, action: Callable) -> Button:
	var chip := Button.new()
	chip.text = title
	chip.custom_minimum_size = touch_minimum(Vector2(64, 26))
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fill := GOLD if active else Color("254e6b")
	chip.add_theme_font_override("font", FONT_BOLD)
	chip.add_theme_font_size_override("font_size", 20 if is_handheld() else 11)
	chip.add_theme_color_override("font_color", Color("fff6d8") if active else TEXT)
	punch_text(chip, 20 if is_handheld() else 11)
	var style := panel_style(fill, fill.lightened(0.15), 8, 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("normal", style)
	chip.add_theme_stylebox_override("hover", panel_style(fill.lightened(0.10), GOLD, 8, 1))
	chip.add_theme_stylebox_override("pressed", panel_style(fill.darkened(0.12), TEXT, 8, 1))
	chip.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	return chip

func roster_filter_bar() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	row.add_child(roster_filter_chip("位置", roster_filter_kind == "pos", func():
		roster_filter_kind = "pos"
		show_roster()
	))
	row.add_child(roster_filter_chip("出身", roster_filter_kind == "origin", func():
		roster_filter_kind = "origin"
		show_roster()
	))
	row.add_child(roster_filter_chip("OVR", roster_filter_kind == "ovr", func():
		roster_filter_kind = "ovr"
		show_roster()
	))
	if not roster_filters_clear():
		row.add_child(roster_filter_chip("清除", false, func():
			roster_filter_pos = ""
			roster_filter_origin = ""
			roster_filter_ovr = 0
			show_roster()
		))
	if roster_filter_kind == "origin":
		row.add_child(roster_filter_chip("全部", roster_filter_origin.is_empty(), func():
			roster_filter_origin = ""
			show_roster()
		))
		for origin: String in roster_origin_options():
			var oid: String = origin
			row.add_child(roster_filter_chip(team_short_name(oid), roster_filter_origin == oid, func():
				roster_filter_origin = "" if roster_filter_origin == oid else oid
				show_roster()
			))
	elif roster_filter_kind == "ovr":
		row.add_child(roster_filter_chip("全部", roster_filter_ovr == 0, func():
			roster_filter_ovr = 0
			show_roster()
		))
		for spec: Array in [[86, "86+"], [81, "81+"], [76, "76+"], [71, "71+"], [-70, "70↓"]]:
			var want: int = int(spec[0])
			var label_txt: String = str(spec[1])
			row.add_child(roster_filter_chip(label_txt, roster_filter_ovr == want, func():
				roster_filter_ovr = 0 if roster_filter_ovr == want else want
				show_roster()
			))
	else:
		row.add_child(roster_filter_chip("全部", roster_filter_pos.is_empty(), func():
			roster_filter_pos = ""
			show_roster()
		))
		for pos: String in ["PG", "SG", "SF", "PF", "C"]:
			var key: String = pos
			row.add_child(roster_filter_chip(pos, roster_filter_pos == key, func():
				roster_filter_pos = "" if roster_filter_pos == key else key
				show_roster()
			))
	return h_chip_scroll(row)

func roster_pick_row(index: int, player: Dictionary) -> Control:
	var selected := index == selected_foundation
	var swapping := index == swap_pick
	var accent := ORANGE if swapping else (GOLD if selected else CYAN)
	var hit := Button.new()
	hit.text = ""
	hit.custom_minimum_size = Vector2(0, 48 if compact_phone() else 56)
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", panel_style(Color(0.07, 0.11, 0.16, 0.82), accent.darkened(0.25 if selected or swapping else 0.45), 10, 2 if selected or swapping else 1))
	hit.add_theme_stylebox_override("hover", panel_style(Color(0.10, 0.14, 0.20, 0.5), accent, 10, 2))
	hit.add_theme_stylebox_override("pressed", panel_style(Color(0.04, 0.06, 0.09, 0.9), TEXT, 10, 1))
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 10
	line.offset_right = -10
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 10)
	hit.add_child(line)
	line.add_child(simple_bust(player, 40))
	line.add_child(plain_label(str(player.get("pos", "G")), 14, accent, true))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	var role := "先發" if index < 5 else ("登錄" if index < 12 else "未登錄")
	if swapping:
		role = "互換中"
	var who := identity_label(player)
	var ovr_line := "OVR %d" % int(player.get("ovr", 70))
	words.add_child(plain_label(str(player.get("name", "球員")), 16, TEXT, true))
	words.add_child(plain_label("%s · %s · $%d 萬" % [role, who, int(float(player.get("salary_million", published_salary(player))))], 11, MUTED))
	line.add_child(plain_label(ovr_line, 15, GOLD, true))
	hit.pressed.connect(func():
		play_sfx("tap")
		selected_foundation = index
		if swap_pick < 0 or swap_pick == index:
			swap_pick = -1 if swap_pick == index else index
			show_roster()
			return
		var tmp: Dictionary = team_players[swap_pick]
		team_players[swap_pick] = team_players[index]
		team_players[index] = tmp
		swap_pick = -1
		save_game()
		show_roster()
	)
	bind_press_juice(hit, hit)
	return hit

func release_roster_player(index: int, confirmed := false) -> void:
	if index < 0 or index >= team_players.size() or team_players.size() <= minimum_roster_to_play():
		flash_notice("至少保留 7 人才能開打")
		return
	var gone: Dictionary = team_players[index]
	if is_locked_prize(gone):
		flash_notice("鑽石卡不能釋出")
		return
	if not confirmed:
		show_guide_sheet("確認釋出球員", "%s 將永久離開名單。若只是暫時不用，建議放入保管箱。" % gone.get("name", "球員"), RED)
		var target_key := player_identity_key(gone)
		var confirm := action_button("確定永久釋出", RED, func():
			close_guide_modal()
			if index < team_players.size() and player_identity_key(team_players[index]) == target_key:
				release_roster_player(index, true)
		)
		var box := guide_modal.find_child("GuideBody", true, false)
		if box != null:
			box.add_child(confirm)
		else:
			confirm.free()
		return
	team_players.remove_at(index)
	selected_foundation = clampi(selected_foundation, 0, team_players.size() - 1)
	apply_combo_label()
	last_event = "%s 已釋出，離開名單。" % gone.get("name", "球員")
	save_game()
	show_roster()

func vault_filters_clear() -> bool:
	return vault_filter_pos.is_empty() and vault_filter_origin.is_empty() and vault_filter_ovr == 0 and vault_filter_tier.is_empty()

func vault_matches_filter(player: Dictionary) -> bool:
	if not vault_filter_pos.is_empty() and vault_filter_pos not in player_pos_list(player):
		return false
	if not vault_filter_origin.is_empty() and origin_id(player) != vault_filter_origin:
		return false
	var ovr := int(player.get("ovr", 70))
	if vault_filter_ovr > 0 and ovr < vault_filter_ovr:
		return false
	if vault_filter_ovr < 0 and ovr > absi(vault_filter_ovr):
		return false
	if not vault_filter_tier.is_empty() and player_tier_key(player) != vault_filter_tier:
		return false
	return true

func vault_origin_options() -> Array[String]:
	var seen: Dictionary = {}
	var ids: Array[String] = []
	for raw in card_inventory:
		if not (raw is Dictionary):
			continue
		var origin := origin_id(raw)
		if origin.is_empty() or seen.has(origin):
			continue
		seen[origin] = true
		ids.append(origin)
	ids.sort_custom(func(a, b): return team_short_name(a) < team_short_name(b))
	return ids

func vault_filter_bar() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	row.add_child(roster_filter_chip("排序：" + vault_sort_label(), false, func(): cycle_vault_sort()))
	row.add_child(roster_filter_chip("位置", vault_filter_kind == "pos", func():
		vault_filter_kind = "pos"
		show_card_vault()
	))
	row.add_child(roster_filter_chip("出身", vault_filter_kind == "origin", func():
		vault_filter_kind = "origin"
		show_card_vault()
	))
	row.add_child(roster_filter_chip("OVR", vault_filter_kind == "ovr", func():
		vault_filter_kind = "ovr"
		show_card_vault()
	))
	row.add_child(roster_filter_chip("卡色", vault_filter_kind == "tier", func():
		vault_filter_kind = "tier"
		show_card_vault()
	))
	if not vault_filters_clear():
		row.add_child(roster_filter_chip("清除", false, func():
			vault_filter_pos = ""
			vault_filter_origin = ""
			vault_filter_ovr = 0
			vault_filter_tier = ""
			show_card_vault()
		))
	if vault_filter_kind == "origin":
		row.add_child(roster_filter_chip("全部", vault_filter_origin.is_empty(), func():
			vault_filter_origin = ""
			show_card_vault()
		))
		for origin: String in vault_origin_options():
			var oid: String = origin
			row.add_child(roster_filter_chip(team_short_name(oid), vault_filter_origin == oid, func():
				vault_filter_origin = "" if vault_filter_origin == oid else oid
				show_card_vault()
			))
	elif vault_filter_kind == "ovr":
		row.add_child(roster_filter_chip("全部", vault_filter_ovr == 0, func():
			vault_filter_ovr = 0
			show_card_vault()
		))
		for spec: Array in [[86, "86+"], [81, "81+"], [76, "76+"], [71, "71+"], [-70, "70↓"]]:
			var want: int = int(spec[0])
			var label_txt: String = str(spec[1])
			row.add_child(roster_filter_chip(label_txt, vault_filter_ovr == want, func():
				vault_filter_ovr = 0 if vault_filter_ovr == want else want
				show_card_vault()
			))
	elif vault_filter_kind == "tier":
		row.add_child(roster_filter_chip("全部", vault_filter_tier.is_empty(), func():
			vault_filter_tier = ""
			show_card_vault()
		))
		for spec: Array in [["cyan", "青"], ["green", "綠"], ["blue", "藍"], ["red", "紅"], ["purple", "紫"], ["gold", "金"], ["diamond", "鑽"]]:
			var key: String = str(spec[0])
			var mark: String = str(spec[1])
			row.add_child(roster_filter_chip(mark, vault_filter_tier == key, func():
				vault_filter_tier = "" if vault_filter_tier == key else key
				show_card_vault()
			))
	else:
		row.add_child(roster_filter_chip("全部", vault_filter_pos.is_empty(), func():
			vault_filter_pos = ""
			show_card_vault()
		))
		for pos: String in ["PG", "SG", "SF", "PF", "C"]:
			var key: String = pos
			row.add_child(roster_filter_chip(pos, vault_filter_pos == key, func():
				vault_filter_pos = "" if vault_filter_pos == key else key
				show_card_vault()
			))
	return h_chip_scroll(row)

func show_card_vault() -> void:
	active_menu = "vault"
	var content := begin_screen("保管箱", "箱內不算薪資帽。點卡登錄；滿員或超帽時點卡換人。", 4)
	content.add_child(combo_status_banner(true))
	var chips := HBoxContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("separation", 6)
	content.add_child(chips)
	chips.add_child(roster_count_pill("保管箱", "%d／%d" % [card_inventory.size(), vault_capacity()], GOLD))
	chips.add_child(roster_count_pill("名單", "%d／%d" % [team_players.size(), roster_limit()], CYAN))
	chips.add_child(action_button("擴充 +10", GOLD, func(): select_store_product("便利功能", "vault_plus_10"), Vector2(94, 38)))
	var filters: Control = vault_filter_bar()
	filters.visible = not is_handheld() or vault_filters_visible
	content.add_child(filters)
	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_stylebox_override("panel", panel_style(Color(0.04, 0.06, 0.09, 0.52), Color(0.96, 0.78, 0.32, 0.18), 16, 1))
	var inner: Control
	if card_inventory.is_empty():
		var empty := VBoxContainer.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.add_theme_constant_override("separation", 6)
		empty.add_child(fit_label("球探或市場滿 12 / 超帽會進這裡。", 13, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
		inner = empty
	else:
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		var card_w := lobby_card_width(true)
		var shown := 0
		for i in sorted_vault_indices():
			if not (card_inventory[i] is Dictionary):
				continue
			var player: Dictionary = to_game_player(card_inventory[i])
			if not vault_matches_filter(player):
				continue
			var idx := i
			var entry := VBoxContainer.new()
			entry.name = "VaultPlayerEntry_%d" % idx
			entry.custom_minimum_size = Vector2(card_w, 0)
			entry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			entry.add_theme_constant_override("separation", 3)
			entry.add_child(lobby_player_card(player, false, -1, false, card_w, func():
				show_player_sheet(player, func(): show_card_vault(), func(): place_from_vault(idx), "登錄球隊")
			))
			var login := action_button(vault_login_tag(player), CYAN if can_sign_player(player, true).is_empty() else ORANGE, func():
				place_from_vault(idx)
			, Vector2(card_w, 38))
			login.name = "VaultLoginButton"
			login.tooltip_text = "直接登錄；若名單已滿、超薪資帽或資格受限，會進入換人選擇。"
			login.add_theme_font_size_override("font_size", 13 if is_handheld() else 11)
			entry.add_child(login)
			if can_release_duplicate(player):
				var release_reward := duplicate_gold_for(player)
				var release := action_button("釋出 +%d 黃金" % release_reward, GOLD, func(): release_vault_player(idx), Vector2(card_w, 34))
				release.name = "ReleaseDuplicateButton"
				release.tooltip_text = "這張是重複卡；釋出後獲得黃金，另一張仍會保留。"
				release.add_theme_font_size_override("font_size", 12 if is_handheld() else 11)
				entry.add_child(release)
			flow.add_child(entry)
			shown += 1
		if shown == 0:
			flow.free()
			var empty := VBoxContainer.new()
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
			empty.alignment = BoxContainer.ALIGNMENT_CENTER
			empty.add_child(fit_label("沒有符合篩選的人，改條件或按全部。", 13, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
			inner = empty
		else:
			inner = flow
	board.add_child(padded(inner, 8))
	content.add_child(board)
	if is_handheld():
		content.move_child(board, 0)
		if vault_filters_visible:
			content.move_child(filters, 0)
	var vault_bar := HBoxContainer.new()
	vault_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vault_bar.add_theme_constant_override("separation", 8)
	if is_handheld():
		var filter_btn := action_button("收起篩選" if vault_filters_visible else "篩選", Color("254e6b"), func():
			vault_filters_visible = not vault_filters_visible
			show_card_vault()
		)
		filter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vault_bar.add_child(filter_btn)
	var roster_btn := gold_action_button("回編隊", func(): show_roster())
	roster_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vault_bar.add_child(roster_btn)
	var more_btn := action_button("回更多", Color("254e6b"), func(): show_more_hub(), Vector2(0, 42))
	more_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vault_bar.add_child(more_btn)
	pin_above_dock(content, vault_bar)

func show_training_modal() -> void:
	if is_instance_valid(training_modal):
		var old := training_modal
		training_modal = null
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
	var overlay := ColorRect.new()
	overlay.name = "TrainingModal"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.03, 0.06, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 40
	training_modal = overlay
	add_child(overlay)

	var dialog := PanelContainer.new()
	dialog.anchor_left = 0.12
	dialog.anchor_top = 0.10
	dialog.anchor_right = 0.88
	dialog.anchor_bottom = 0.90
	dialog.offset_left = 0
	dialog.offset_top = 0
	dialog.offset_right = 0
	dialog.offset_bottom = 0
	dialog.add_theme_stylebox_override("panel", panel_style(Color("0c1927fc"), GREEN, 22, 2))
	overlay.add_child(dialog)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	dialog.add_child(padded(box, 16))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(label("養成", 21, TEXT, true))
	words.add_child(wrap_label("上場滿 3 場後才能特訓；每次消耗 1 點＋$20 萬，成功率 100／90／80／70／50%，最多 5 次", 16, MUTED))
	header.add_child(words)
	var close := action_button("×", Color("27394a"), func(): close_training_modal(), Vector2(48, 48))
	close.add_theme_font_size_override("font_size", 28)
	close.tooltip_text = "關閉"
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	for i in team_players.size():
		rows.add_child(training_row(i, team_players[i]))

func training_row(index: int, player: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 76)
	row.add_theme_stylebox_override("panel", panel_style(Color("112536ef"), GREEN.darkened(0.35), 14, 1))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(padded(line, 9))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(label("%s  ·  %s" % [player.get("name", "球員"), player.get("pos", "SG")], 15, TEXT, true))
	info.add_child(wrap_label("OVR %d  ·  遊戲年薪 $%d 萬  ·  已訓練 %d／%d 次  ·  上場 %d／3 場" % [int(player.get("ovr", 70)), int(float(player.get("salary_million", published_salary(player)))), int(player.get("training_sessions", 0)), TRAINING_MAX_SESSIONS, int(player.get("match_appearances", 0))], 11, MUTED))
	line.add_child(info)
	var train := action_button("訓練", GREEN, func(): apply_player_training(index), Vector2(88, 48))
	train.disabled = training_points < 1 or budget_million < 20 or int(player.get("ovr", 70)) >= 90 or int(player.get("training_sessions", 0)) >= TRAINING_MAX_SESSIONS or int(player.get("match_appearances", 0)) < 3
	line.add_child(train)
	return row

func apply_player_training(index: int, reopen_modal := true) -> void:
	if index < 0 or index >= team_players.size():
		return
	if training_points < 1:
		flash_notice("特訓點不足：贏一場才會拿到 1 點")
		return
	if budget_million < 20:
		flash_notice("資金不足：本次養成需 $20 萬，目前 $%d 萬。" % budget_million)
		return
	var player: Dictionary = team_players[index]
	var old_ovr := int(player.get("ovr", 70))
	var old_tier := player_tier_key(player)
	var sessions := int(player.get("training_sessions", 0))
	if sessions >= TRAINING_MAX_SESSIONS:
		flash_notice("%s 已完成 5 次特訓，專屬技能已解鎖並套用到比賽。" % player.get("name", "球員"))
		return
	var appearances := int(player.get("match_appearances", 0))
	if appearances < 3:
		flash_notice("%s 還需要上場 %d 場才能特訓。" % [player.get("name", "球員"), 3 - appearances])
		return
	if int(player.get("ovr", 70)) >= 90:
		flash_notice("%s 已達 OVR 90 養成上限" % player.get("name", "球員"))
		return
	var trained := player.duplicate(true)
	trained["ovr"] = mini(90, int(player.get("ovr", 70)) + 1)
	trained["training_sessions"] = int(player.get("training_sessions", 0)) + 1
	var new_salary := published_salary(trained)
	if roster_salary() - int(player.get("salary_million", 0)) + new_salary > salary_cap:
		flash_notice("養成後年薪 $%d 萬會超過薪資帽，請先調整名單；尚未扣點或資金。" % new_salary)
		return
	var success_rate: float = [1.0, 0.9, 0.8, 0.7, 0.5][sessions]
	var server_authorized := server_spend_authorized
	if not auth_access.is_empty() and not server_authorized:
		if not server_spend_inflight:
			request_server_economy_spend("training", -20, 0, 0, -1, func(ok: bool):
				if not ok:
					return
				call_deferred("apply_player_training", index, reopen_modal)
			)
		return
	server_spend_authorized = false
	if not server_authorized:
		training_points -= 1
		budget_million -= 20
	if randf() > success_rate:
		player["training_attempts"] = int(player.get("training_attempts", 0)) + 1
		last_training_note = "%s 特訓未突破（成功率 %d%%）；特訓點與資金已使用。" % [player.get("name", "球員"), int(success_rate * 100.0)]
		last_event = last_training_note
		last_news = last_event
		save_game()
		flash_notice(last_training_note)
		if reopen_modal:
			call_deferred("show_training_modal")
		return
	player["ovr"] = mini(90, int(player.get("ovr", 70)) + 1)
	player["training_sessions"] = sessions + 1
	player["salary_million"] = published_salary(player)
	player["color"] = player_tier_key(player)
	team_players[index] = player
	var skill := str(player.get("skill_id", ""))
	var note := "對抗更穩"
	if skill in ["three_and_d", "corner_three"]:
		note = "外線更穩"
	elif skill in ["glass_cleaner", "screen_hub"]:
		note = "禁區卡位更到位"
	elif skill in ["floor_general", "playmaker"]:
		note = "組織更清楚"
	elif skill == "veteran_leadership":
		note = "領導更穩"
	var next_text := " · 專屬技能已解鎖並套用到比賽" if int(player.get("training_sessions", 0)) >= TRAINING_MAX_SESSIONS else ""
	last_training_note = "%s 練完：%s（OVR %d · 特訓 +%d · 年薪 $%d 萬）%s" % [player.get("name", "球員"), note, player.get("ovr", 70), int(player.get("training_sessions", 0)), int(float(player.get("salary_million", 0))), next_text]
	last_event = last_training_note
	last_news = last_event
	save_game()
	var new_tier := player_tier_key(player)
	if reopen_modal and new_tier != old_tier:
		call_deferred("show_tier_up_reveal", player.duplicate(true), old_tier, old_ovr, func(): show_training_modal())
	elif reopen_modal:
		call_deferred("show_training_modal")

func close_training_modal() -> void:
	if is_instance_valid(training_modal):
		call_deferred("_finish_close_training",training_modal.get_instance_id())

func _finish_close_training(expected_id: int) -> void:
	# A delayed close must not replace a newer page or a different modal.
	if not is_instance_valid(training_modal) or training_modal.get_instance_id() != expected_id:
		return
	if is_instance_valid(training_modal):
		var old := training_modal
		training_modal = null
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
	training_modal = null
	show_roster()

func show_tactics() -> void:
	active_menu = "tactics"
	refresh_tactic_unlocks()
	var opponent: Dictionary = current_match_opponent() if not opponents.is_empty() else {}
	var content := begin_screen("戰術", "只顯示已解鎖打法。對上對方攻守才知道怎麼相剋。", 4)
	if not opponent.is_empty():
		content.add_child(tonight_matchup_panel(opponent))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	var offense := VBoxContainer.new()
	offense.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offense.add_theme_constant_override("separation", 8)
	columns.add_child(offense)
	offense.add_child(label("進攻", 18, ORANGE, true))
	for item in tactic_catalog("offense"):
		if not (item is Dictionary):
			continue
		var play := str(item.get("id", ""))
		if not tactic_unlocked_now(play, true):
			continue
		var how := str(item.get("how", tactic_description(play)))
		var chosen := play == selected_tactic
		var vs := tonight_vs_note(play, true, opponent) if not opponent.is_empty() else ""
		var note := vs if not vs.is_empty() else ("使用中" if chosen else "點選套用")
		if chosen and not vs.is_empty():
			note = "使用中 · " + vs
		offense.add_child(hub_tile(play, how, note, GOLD if chosen else MUTED, func():
			selected_tactic = play
			save_game()
			show_tactics()
		, {}, false, "", chosen))
	var defense := VBoxContainer.new()
	defense.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defense.add_theme_constant_override("separation", 8)
	columns.add_child(defense)
	defense.add_child(label("防守", 18, CYAN, true))
	for item in tactic_catalog("defense"):
		if not (item is Dictionary):
			continue
		var cover := str(item.get("id", ""))
		if not tactic_unlocked_now(cover, false):
			continue
		var how_d := str(item.get("how", tactic_description(cover)))
		var chosen_d := cover == selected_defense
		var vs_d := tonight_vs_note(cover, false, opponent) if not opponent.is_empty() else ""
		var note_d := vs_d if not vs_d.is_empty() else ("使用中" if chosen_d else "點選套用")
		if chosen_d and not vs_d.is_empty():
			note_d = "使用中 · " + vs_d
		defense.add_child(hub_tile(cover, how_d, note_d, GOLD if chosen_d else MUTED, func():
			selected_defense = cover
			save_game()
			show_tactics()
		, {}, false, "", chosen_d))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	content.add_child(bottom)
	bottom.add_child(action_button("任務", Color("254e6b"), func(): open_sub(show_tactics, show_challenge_hub), Vector2(0, 50)))
	bottom.add_child(action_button("去賽前開打", ORANGE, func():
		clear_return_stack()
		show_match_prep()
	, Vector2(0, 50)))

func show_match_prep() -> void:
	prep_extra_event = ""
	if match_rewards_pending:
		show_match_presentation()
		return
	ensure_season_scout()
	active_menu = "match"
	for i in team_players.size():
		if team_players[i] is Dictionary:
			team_players[i] = refresh_stored_player(team_players[i])
	ensure_photographed_starters()
	var opponent: Dictionary = current_match_opponent()
	if is_handheld():
		show_phone_match_prep(opponent)
		return
	var opp_club := opponent_club(opponent)
	var opp_starters := opponent_starting_five(opponent)
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	var opp_off := str(style.get("offense", "半場傳導"))
	var opp_def := str(style.get("defense", "人盯人"))
	var content := begin_screen("賽前", "%s VS %s" % [club_display_name(), str(opponent.get("name", "對手"))], 5)
	fill_scroll_body(content)
	var middle := HBoxContainer.new()
	middle.name = "MatchPrepLandscapeBody"
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	content.add_child(middle)
	middle.add_child(match_prep_roster_col("對方先發", opp_starters, CYAN, func(player: Dictionary):
		show_player_sheet(player, func(): show_match_prep())
	, "完整名單" if not opp_club.is_empty() else "", func():
		open_sub(show_match_prep, func(): show_team_profile(opp_club, "全部"))
	, -1, "攻 %s　守 %s" % [opp_off, opp_def]))

	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_stretch_ratio = 1.15
	board.add_theme_stylebox_override("panel", panel_style(Color("0a1622e8"), ORANGE, 16, 2))
	middle.add_child(board)
	var board_box := VBoxContainer.new()
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_box.add_theme_constant_override("separation", 6)
	board.add_child(padded(board_box, 10))
	board_box.add_child(plain_label("今晚對戰", 16, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var poster := HBoxContainer.new()
	poster.alignment = BoxContainer.ALIGNMENT_CENTER
	poster.add_theme_constant_override("separation", 10)
	board_box.add_child(poster)
	var home_col := VBoxContainer.new()
	home_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_col.alignment = BoxContainer.ALIGNMENT_CENTER
	home_col.add_theme_constant_override("separation", 2)
	home_col.add_child(team_logo_rect(ensure_club_logo_id(), 44, club_display_name()))
	home_col.add_child(plain_label("主場" if is_home_game else "客場", 11, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	poster.add_child(home_col)
	var vs_col := VBoxContainer.new()
	vs_col.alignment = BoxContainer.ALIGNMENT_CENTER
	vs_col.add_child(plain_label("VS", 22, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	poster.add_child(vs_col)
	var away_col := VBoxContainer.new()
	away_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	away_col.alignment = BoxContainer.ALIGNMENT_CENTER
	away_col.add_theme_constant_override("separation", 2)
	away_col.add_child(team_logo_rect(str(opponent.get("team_id", "")), 44, str(opponent.get("name", "球"))))
	away_col.add_child(fit_label(str(opponent.get("name", "對手")), 12, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	poster.add_child(away_col)
	board_box.add_child(plain_label(fixture_label(), 13, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	board_box.add_child(plain_label(home_court_line(), 12, GREEN if is_home_game else MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	if team_players.size() < minimum_roster_to_play():
		board_box.add_child(callout("人數不足", "%s；保管箱不會自動補回球員。" % roster_availability_line(), RED))
	elif not can_field_five():
		board_box.add_child(callout("外援限制", gameday_roster_warning(), RED))
	elif over_salary_cap():
		board_box.add_child(callout("超帽", "已超薪資帽，先去編隊調整名單才能開打。", RED))
	else:
		board_box.add_child(callout("輪替深度", roster_availability_line(), CYAN))
		var miss := lineup_mismatch_line()
		if not miss.is_empty():
			board_box.add_child(callout("陣容", miss, RED))
	if not opponent.is_empty():
		board_box.add_child(tonight_matchup_panel(opponent))
		board_box.add_child(callout("勝負預估", pregame_factor_summary(opponent), CYAN))
	var play := play_start_button(func(): try_start_match(), Vector2(0, 48))
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.disabled = team_players.size() < minimum_roster_to_play() or not can_field_five() or over_salary_cap()
	board_box.add_child(play)
	board_box.add_child(hub_tile("今晚打法", "對方攻%s　守%s" % [opp_off, opp_def], "點進去改戰術相剋", ORANGE, func(): open_sub(show_match_prep, show_tactics), {}, true))
	board_box.add_child(hub_tile("換人", "先發、替補在編隊互換", "點兩張卡對調", CYAN, func(): open_sub(show_match_prep, show_roster), {}, true))

	var mine: Array = []
	for i in mini(team_players.size(), 5):
		mine.append(team_players[i])
	middle.add_child(match_prep_roster_col("我方先發", mine, GOLD, func(player: Dictionary):
		var idx := team_players.find(player)
		if idx < 0:
			for i in team_players.size():
				if str(team_players[i].get("name", "")) == str(player.get("name", "")):
					idx = i
					break
		if idx >= 0:
			show_owned_player(idx)
		else:
			show_player_sheet(player, func(): show_match_prep())
	, "去編隊", func(): open_sub(show_match_prep, show_roster), 0))

func show_phone_match_prep(opponent: Dictionary, extra := false) -> void:
	prep_extra_event = extra_event if extra else ""
	active_menu = "match"
	var back: Callable = show_extra_match_prep if extra else show_match_prep
	var content := begin_screen("賽前準備", "額外比賽 · " + extra_entry_label(extra_event) if extra else fixture_label(), 5)
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	var mine: Array = team_players.slice(0, mini(5, team_players.size()))
	var theirs := opponent_starting_five(opponent)
	content.add_child(phone_match_court(opponent, mine, theirs, style))
	content.add_child(callout("勝負預估", pregame_factor_summary(opponent), CYAN))
	var blocked := team_players.size() < minimum_roster_to_play() or not can_field_five() or over_salary_cap()
	if blocked:
		var reason := "至少需要 7 名球員，且登錄薪資不得超帽。請先調整陣容。"
		if not can_field_five():
			reason = gameday_roster_warning()
		content.add_child(wrap_label(reason, 14, ORANGE))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	if not extra and not playoff_state.is_empty():
		actions.add_child(action_button("系列賽", CYAN, show_playoff_bracket, Vector2(100, 44)))
	var play := gold_action_button("開始比賽", func(): start_extra_match() if extra else try_start_match())
	play.disabled = blocked
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.size_flags_stretch_ratio = 1.3
	actions.add_child(play)
	for spec in [["調整陣容", show_roster], ["選擇戰術", show_tactics]]:
		var destination: Callable = spec[1]
		var button := action_button(str(spec[0]), Color("254052"), func(): open_sub(back, destination))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	pin_above_dock(content, actions)

func phone_match_court(opponent: Dictionary, mine: Array, theirs: Array, style: Dictionary) -> Control:
	var shell := VBoxContainer.new()
	shell.name = "MatchPrepLineups"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 3)
	var identity := HBoxContainer.new()
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 7)
	shell.add_child(identity)
	var home := HBoxContainer.new()
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.add_theme_constant_override("separation", 4)
	home.add_child(team_logo_rect(ensure_club_logo_id(), 30, club_name))
	var combo := combo_state()
	if not combo.is_empty():
		home.add_child(team_logo_rect(str(combo.get("origin", "")), 26, str(combo.get("label", "組合隊伍"))))
	home.add_child(fit_label("%s · OVR %d" % [club_display_name(), roundi(average_ovr())], 13, GOLD, true))
	identity.add_child(home)
	identity.add_child(plain_label("VS", 18, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	var away := HBoxContainer.new()
	away.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	away.alignment = BoxContainer.ALIGNMENT_END
	away.add_theme_constant_override("separation", 4)
	away.add_child(fit_label("%s · OVR %d" % [str(opponent.get("name", "對手")), int(opponent.get("rating", 70))], 13, CYAN, true, HORIZONTAL_ALIGNMENT_RIGHT))
	away.add_child(team_logo_rect(str(opponent.get("team_id", "")), 30, str(opponent.get("name", "對手"))))
	identity.add_child(away)
	var tactics := fit_label("我方：攻 %s／守 %s　　對方：攻 %s／守 %s" % [selected_tactic, selected_defense, str(style.get("offense", "半場傳導")), str(style.get("defense", "人盯人"))], 11, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	tactics.name = "PregameTacticsSummary"
	shell.add_child(tactics)
	var court := BasketballCourtBoard.new()
	court.name = "FullCourt"
	court.custom_minimum_size = Vector2(0, UI_MATCH_COURT_HEIGHT_PHONE if compact_phone() else UI_MATCH_COURT_HEIGHT_DESKTOP)
	court.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	court.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(court)
	# Starters use the upper playing area; the taller lower lane is reserved for
	# both benches so the preparation page uses the full phone canvas.
	var home_spots := [Vector2(0.39, 0.35), Vector2(0.30, 0.13), Vector2(0.30, 0.53), Vector2(0.17, 0.21), Vector2(0.14, 0.48)]
	var away_spots := [Vector2(0.61, 0.35), Vector2(0.70, 0.53), Vector2(0.70, 0.13), Vector2(0.83, 0.48), Vector2(0.86, 0.21)]
	for side in 2:
		var roster: Array = mine if side == 0 else theirs
		var spots: Array = home_spots if side == 0 else away_spots
		for i in mini(5, roster.size()):
			var captured_player: Dictionary = roster[i]
			var captured_home := side == 0
			var card := lobby_player_card(captured_player, true, i if captured_home else -1, false, 60, func():
				if captured_home:
					var owned_i := team_players.find(captured_player)
					if owned_i >= 0:
						show_owned_player(owned_i)
				else:
					show_player_sheet(captured_player, func(): show_phone_match_prep(opponent, bool(opponent.get("extra", false))))
			)
			card.anchor_left = spots[i].x
			card.anchor_right = spots[i].x
			card.anchor_top = spots[i].y
			card.anchor_bottom = spots[i].y
			card.offset_left = -21
			card.offset_right = 21
			card.offset_top = -31
			card.offset_bottom = 31
			court.add_child(card)
	var opponent_roster: Array = extra_team_players(str(opponent.get("team_id", "")))
	if opponent_roster.is_empty() and opponent.get("players", []) is Array:
		opponent_roster = opponent.get("players", []).duplicate(true)
	for side in 2:
		var bench_box := VBoxContainer.new()
		bench_box.name = "HomeBench" if side == 0 else "AwayBench"
		bench_box.anchor_left = 0.02 if side == 0 else 0.52
		bench_box.anchor_right = 0.48 if side == 0 else 0.98
		bench_box.anchor_top = 0.65
		bench_box.anchor_bottom = 0.99
		bench_box.offset_left = 0
		bench_box.offset_right = 0
		bench_box.offset_top = 0
		bench_box.offset_bottom = 0
		bench_box.alignment = BoxContainer.ALIGNMENT_END
		bench_box.add_theme_constant_override("separation", 1)
		court.add_child(bench_box)
		bench_box.add_child(fit_label("我方替補" if side == 0 else "對方替補", 10, GOLD if side == 0 else CYAN, true, HORIZONTAL_ALIGNMENT_CENTER))
		var bench_row := HBoxContainer.new()
		bench_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bench_row.add_theme_constant_override("separation", 2)
		bench_box.add_child(bench_row)
		var bench_roster: Array = team_players if side == 0 else opponent_roster
		var bench_end := mini(10, bench_roster.size())
		for i in range(5, bench_end):
			var bench_player: Dictionary = bench_roster[i]
			var bench_home := side == 0
			var bench_press := Callable(self, "open_pregame_bench_player").bind(opponent.duplicate(true), bench_player.duplicate(true), i, bench_home)
			var bench_card := lobby_player_card(bench_player, false, i if bench_home else -1, false, 60, bench_press)
			bench_row.add_child(bench_card)
		if bench_row.get_child_count() == 0:
			bench_row.add_child(fit_label("尚無替補資料", 10, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	return shell

func open_pregame_bench_player(opponent: Dictionary, player: Dictionary, index: int, is_ours: bool) -> void:
	if is_ours:
		show_owned_player(index)
		return
	show_player_sheet(player, func(): show_phone_match_prep(opponent, bool(opponent.get("extra", false))))

func compact_match_lineup(title: String, players: Array, offense: String, defense: String, accent: Color, rating: int) -> Control:
	var col := VBoxContainer.new()
	col.name = "PrepRoster"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	col.add_theme_constant_override("separation", 3)
	col.add_child(fit_label(title, 16, accent, true))
	col.add_child(fit_label("OVR %d · 攻 %s" % [rating, offense], 14, TEXT))
	col.add_child(fit_label("守 %s" % defense, 14, MUTED))
	if players.is_empty():
		col.add_child(wrap_label("先發名單尚未收錄；本場以隊伍 OVR 模擬，不冒用其他球隊球員。", 14, MUTED))
	for i in mini(5, players.size()):
		var player: Dictionary = players[i]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 26
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		var position := plain_label(str(player.get("pos", "—")), 13, accent, true)
		position.custom_minimum_size.x = 34
		row.add_child(position)
		var who := fit_label(str(player.get("name", "球員")), 14, TEXT)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		row.add_child(plain_label(str(player.get("ovr", "—")), 16, TEXT, true))
	return col

func show_extra_match_prep() -> void:
	if match_rewards_pending:
		show_match_presentation()
		return
	if extra_queue.is_empty():
		flash_notice("沒有下一場")
		return
	show_phone_match_prep(extra_rival_from(extra_queue[0]), true)

func try_start_match() -> void:
	call_deferred("_try_start_match_now")

func _try_start_match_now() -> void:
	if season_phase == "offseason":
		show_offseason()
		return
	if season_phase == "champion":
		show_trophy()
		return
	if team_players.size() < minimum_roster_to_play():
		flash_notice("至少保留 7 人才能開打，目前只有 %d 人。" % team_players.size())
		show_roster()
		return
	if not can_field_five():
		flash_notice(gameday_roster_warning())
		show_roster()
		return
	if over_salary_cap():
		flash_notice("已超薪資帽，先去編隊調整名單才能開打。")
		show_roster()
		return
	start_match()

func skill_profile(skill_id: String) -> Dictionary:
	match skill_id:
		"lu_69_demon": return {"name":"69大魔王", "description":"落後時提升三分球出手次數與命中率，逆風回合更容易追分。", "offense":1.15, "defense":0.0, "q4":0.75, "chemistry":0.1}
		"floor_general": return {"name":"節奏大師", "description":"提高團隊默契，降低比賽失誤波動。", "offense":0.8, "defense":0.1, "q4":0.2, "chemistry":1.2}
		"three_and_d": return {"name":"定點砲台", "description":"空檔外線更穩定；快節奏戰術額外放大。", "offense":0.35, "defense":0.25, "q4":0.2, "chemistry":0.2}
		"glass_cleaner": return {"name":"禁區卡位", "description":"籃板回合更穩定，末節防守小幅提升。", "offense":0.15, "defense":0.65, "q4":0.6, "chemistry":0.4}
		"screen_hub": return {"name":"高位策應", "description":"擋拆與二次進攻更有效。", "offense":0.55, "defense":0.15, "q4":0.2, "chemistry":0.4}
		"playmaker": return {"name":"二次助攻", "description":"提高助攻與球權分享，讓進攻更平滑。", "offense":0.55, "defense":0.05, "q4":0.15, "chemistry":0.8}
		"two_way_wing": return {"name":"雙向側翼", "description":"攻守兩端都提供穩定的小幅加成。", "offense":0.35, "defense":0.5, "q4":0.25, "chemistry":0.35}
		"corner_three": return {"name":"底角埋伏", "description":"低使用率陣容也能提供外線效率。", "offense":0.3, "defense":0.1, "q4":0.15, "chemistry":0.1}
		"transition": return {"name":"轉換引擎", "description":"快攻回合增加，適合快速推進。", "offense":0.4, "defense":0.2, "q4":0.3, "chemistry":0.2}
		"clutch": return {"name":"關鍵回合", "description":"末節比分接近時，關鍵回合評價提升。", "offense":0.2, "defense":0.2, "q4":1.8, "chemistry":0.25}
		"volume_scorer": return {"name":"持球火力", "description":"提高進攻上限，但高回合下失誤風險上升。", "offense":0.95, "defense":0.0, "q4":0.45, "chemistry":-0.15}
		"bench_spark": return {"name":"替補火花", "description":"輪替登場時提升活力與攻守連貫。", "offense":0.3, "defense":0.2, "q4":0.35, "chemistry":0.45}
		"lockdown": return {"name":"外圍鎖鏈", "description":"降低對手外線效率，對射手型對手更有效。", "offense":0.05, "defense":1.1, "q4":0.25, "chemistry":0.2}
		"hustle": return {"name":"拼搶能量", "description":"提升抄截與失誤轉換事件機率。", "offense":0.2, "defense":0.55, "q4":0.25, "chemistry":0.35}
		"veteran_leadership": return {"name":"老將領導", "description":"提升年輕球員士氣，降低逆風默契損失。", "offense":0.1, "defense":0.25, "q4":0.4, "chemistry":1.5}
		"team_ovr_aura": return {"name":"全隊加持", "description":"在登錄名單時，全隊 OVR +1。", "offense":0.4, "defense":0.4, "q4":0.2, "chemistry":0.8}
		_: return {"name":"即戰力", "description":"沒有特殊技能。", "offense":0.0, "defense":0.0, "q4":0.0, "chemistry":0.0}

func team_skill_modifiers() -> Dictionary:
	return lineup_skill_profile(active_match_players(mini(reveal_quarter, 3)), selected_tactic, selected_defense)


func team_skill_summary() -> String:
	var names: Array[String] = []
	for player in team_players:
		var skill_id := str(player.get("skill_id", ""))
		if not skill_id.is_empty():
			var profile: Dictionary = skill_profile(skill_id)
			var suffix := "" if player_skill_unlocked(player) else "（特訓 +5 解鎖）"
			names.append("%s · %s%s" % [player.get("name", "球員"), profile.get("name", "即戰力"), suffix])
	if names.is_empty():
		return "目前陣容尚未解鎖特殊技能"
	return "\n".join(names.slice(0, 5))

func skill_trigger_base(skill_id: String) -> float:
	match skill_id:
		"lu_69_demon": return 0.32
		"floor_general": return 0.34
		"three_and_d": return 0.30
		"glass_cleaner": return 0.32
		"screen_hub": return 0.29
		"playmaker": return 0.31
		"two_way_wing": return 0.27
		"corner_three": return 0.24
		"transition": return 0.30
		"clutch": return 0.22
		"volume_scorer": return 0.26
		"bench_spark": return 0.23
		"lockdown": return 0.30
		"hustle": return 0.28
		"veteran_leadership": return 0.25
		_: return 0.16

func skill_trigger_probability(player: Dictionary, quarter: int, matchup_bonus: float) -> float:
	return skill_probability_for(player, quarter, matchup_bonus, selected_tactic, selected_defense)

func skill_probability_for(player: Dictionary, quarter: int, matchup_bonus: float, attack: String, defense: String) -> float:
	var skill_id := str(player.get("skill_id", ""))
	var base := skill_trigger_base(skill_id)
	var quarter_factor := 1.0
	if quarter == 4:
		quarter_factor = 1.18
	elif quarter == 1:
		quarter_factor = 0.92
	var tactic_factor := 1.0
	if attack == "快節奏轉換" and skill_id in ["transition", "three_and_d", "volume_scorer"]:
		tactic_factor += 0.30
	if attack == "擋拆進攻" and skill_id in ["floor_general", "screen_hub", "playmaker"]:
		tactic_factor += 0.28
	if defense == "全場壓迫" and skill_id in ["lockdown", "hustle"]:
		tactic_factor += 0.24
	return clampf(base * quarter_factor * tactic_factor + matchup_bonus * 0.035, 0.06, 0.88)

func trigger_skill_event(player: Dictionary, quarter: int, matchup_bonus: float) -> Dictionary:
	return skill_event_for(player, quarter, matchup_bonus, selected_tactic, selected_defense)

func skill_event_for(player: Dictionary, quarter: int, matchup_bonus: float, attack: String, defense: String) -> Dictionary:
	if not player_skill_unlocked(player):
		return {}
	var skill_id := str(player.get("skill_id", ""))
	var probability := skill_probability_for(player, quarter, matchup_bonus, attack, defense)
	if randf() > probability:
		return {}
	var profile: Dictionary = skill_profile(skill_id)
	var effect := {
		"offense": clampf(float(profile.get("offense", 0.0)) * 0.72, -SKILL_INDIVIDUAL_OFFENSE_CAP, SKILL_INDIVIDUAL_OFFENSE_CAP),
		"defense": clampf(float(profile.get("defense", 0.0)) * 0.72, -SKILL_INDIVIDUAL_DEFENSE_CAP, SKILL_INDIVIDUAL_DEFENSE_CAP),
		"q4": clampf(float(profile.get("q4", 0.0)) * (1.15 if quarter == 4 else 0.35), -SKILL_INDIVIDUAL_Q4_CAP, SKILL_INDIVIDUAL_Q4_CAP),
		"chemistry": float(profile.get("chemistry", 0.0)) * 0.25,
		"name": str(profile.get("name", "即戰力")),
		"player": str(player.get("name", "球員")),
		"probability": probability,
	}
	return effect

func human_quarter_story(q: int, fire: Dictionary, our_q: int, their_q: int) -> String:
	var star_name := str(fire.get("name", "先發"))
	var closer := str(closer_player().get("name", star_name))
	var venue := "主場球迷把聲浪拉起來" if is_home_game else "客場氣氛壓過來"
	match q:
		0:
			return "Q1 %s，%s 先把節奏帶起來。" % [venue, star_name]
		1:
			if our_q >= their_q:
				var sub := bench_name_in_quarter(1)
				if not sub.is_empty() and sub != star_name:
					return "Q2 %s 上來輪替，%s 連續出手把分差拉開。" % [sub, star_name]
				return "Q2 %s 連續出手，半場把分差拉開。" % star_name
			return "Q2 對手追分，%s 幫忙止血。" % star_name
		2:
			var bench_star := bench_name_in_quarter(2)
			if not bench_star.is_empty():
				return "Q3 輪替換人，%s 帶第二陣容，先發喘口氣。" % bench_star
			return "Q3 %s 犯規麻煩坐下，輪替硬扛這一節。" % star_name
		_:
			if is_home_game:
				return "Q4 %s 關鍵持球，主場加成吃進這一節。" % closer
			return "Q4 客場末節，%s 自己扛收官。" % closer

func start_match() -> void:
	if match_rewards_pending:
		show_match_presentation()
		return
	if team_players.size() < minimum_roster_to_play():
		flash_notice("至少保留 7 人才能開打，目前只有 %d 人。" % team_players.size())
		show_roster()
		return
	if over_salary_cap():
		flash_notice("已超薪資帽，先去編隊調整名單才能開打。")
		show_roster()
		return
	extra_match = false
	ensure_legacy_playoffs()
	last_opponent = current_match_opponent()
	match_event_log.clear()
	current_skill_modifiers.clear()
	var rng_seed := season_games * 104729 + chemistry * 7919 + opponent_index * 313 + (1 if is_home_game else 0) + Time.get_ticks_msec()
	seed(rng_seed)
	match_defense_changed = false
	match_defense_menu = false
	quarter_scores = [[], []]
	quarter_stories.clear()
	match_threes = [0, 0]
	last_tactic_report = tactic_player_line(last_opponent)
	roll_match_rotation()
	roll_quarters_from(0)
	last_home_points = home_court_bonus()
	last_event = last_tactic_report
	last_news = last_event
	last_score = [0, 0]
	reveal_quarter = 0
	match_rewards_pending = true
	server_settlement_inflight = false
	server_settlement_ready = false
	server_settlement_balance.clear()
	server_settlement_match_id = ""
	save_game()
	play_sfx("whistle")
	show_match_presentation()

func match_live_edge() -> Dictionary:
	var profiles := quarter_match_profiles(mini(reveal_quarter, 3))
	var skills := team_skill_modifiers()
	var opponent: Dictionary = last_opponent if not last_opponent.is_empty() else current_match_opponent()
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	return {"home_edge":float(profiles[0].rating) - float(profiles[1].rating) + float(skills.defense), "attack_matchup":tactic_matchup_bonus(selected_tactic, str(style.defense)), "defense_matchup":defense_matchup_bonus(selected_defense, str(style.offense))}


func roll_quarters_from(start_q: int) -> void:
	if start_q <= 0:
		quarter_scores = [[], []]
		quarter_stories.clear()
		match_event_log.clear()
		current_skill_modifiers = {"triggered":[], "names":[], "cutins":{}, "period_threes":[], "venue":("集中場地" if not extra_match and current_league == "SBL" and season_phase in ["semifinal", "final"] else ("主場" if is_home_game else "客場"))}
	else:
		for scores in quarter_scores:
			scores.resize(start_q)
		quarter_stories.resize(start_q)
		match_event_log.clear()
		current_skill_modifiers["triggered"] = []
		current_skill_modifiers["names"] = []
		var kept: Dictionary = current_skill_modifiers.get("cutins", {}).duplicate(true)
		for key in kept.keys():
			if int(key) > start_q:
				kept.erase(key)
		current_skill_modifiers["cutins"] = kept
		var period_threes: Array = current_skill_modifiers.get("period_threes", [])
		period_threes.resize(start_q)
		current_skill_modifiers["period_threes"] = period_threes
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	for q in range(start_q, 4):
		roll_one_period(q, rng)
	while _quarter_sum(0, quarter_scores[0].size()) == _quarter_sum(1, quarter_scores[1].size()):
		roll_one_period(quarter_scores[0].size(), rng)
	last_tactic_report = tactic_player_line(last_opponent if not last_opponent.is_empty() else current_match_opponent())
	last_skill_event = "技能僅由當節上場球員觸發；雙方使用相同比分規則。"


func _quarter_sum(side: int, n: int) -> int:
	var total := 0
	for i in n:
		total += int(quarter_scores[side][i])
	return total

func can_halftime_adjust() -> bool:
	return reveal_quarter == 2 and not match_defense_changed and int(last_score[0]) < int(last_score[1])

func apply_halftime_tactics() -> void:
	if not can_halftime_adjust():
		match_defense_menu = false
		show_match_presentation()
		return
	match_defense_changed = true
	match_defense_menu = false
	roll_quarters_from(2)
	save_game()
	flash_notice("後半場改為 %s／%s。" % [selected_tactic, selected_defense])
	show_match_presentation()

func apply_in_match_defense(cover: String) -> void:
	selected_defense = cover
	apply_halftime_tactics()

func show_match_presentation() -> void:
	match_play_id += 1
	var ticket := match_play_id
	active_menu = "match"
	var opponent: Dictionary = last_opponent if not last_opponent.is_empty() else current_match_opponent()
	var content := begin_screen("比賽進行中", "%s VS %s · 自動播出" % [club_display_name(), str(opponent.get("name", "對手"))], 6, false)
	var scoreboard := PanelContainer.new()
	scoreboard.custom_minimum_size = Vector2(0, 72 if is_handheld() else 96)
	scoreboard.add_theme_stylebox_override("panel", panel_style(Color("091521f2"), ORANGE if reveal_quarter < match_period_count() else GREEN, 18, 2))
	content.add_child(scoreboard)
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 20)
	scoreboard.add_child(padded(score_row, 8))
	score_row.add_child(team_score(club_display_name(), str(last_score[0]), ORANGE))
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(160, 0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	var q_label := "開場" if reveal_quarter == 0 else period_label(reveal_quarter - 1)
	center.add_child(label(q_label, 15, CYAN, true, HORIZONTAL_ALIGNMENT_CENTER))
	center.add_child(label("VS", 24, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	score_row.add_child(center)
	score_row.add_child(team_score(str(opponent.get("name", "對手")), str(last_score[1]), CYAN))

	var lower := HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 10)
	content.add_child(lower)
	var court := PanelContainer.new()
	court.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	court.size_flags_stretch_ratio = 1.7
	court.add_theme_stylebox_override("panel", panel_style(Color("091521d9"), ORANGE if reveal_quarter > 0 else Color("34526b"), 18, 2))
	lower.add_child(court)
	var court_stage := Control.new()
	court_stage.clip_contents = true
	court_stage.custom_minimum_size = Vector2(0, 148 if is_handheld() else 300)
	court.add_child(court_stage)
	var court_image := TextureRect.new()
	court_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	court_image.texture = load_png_tex("res://assets/ui/half_court.png")
	court_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	court_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	court_image.modulate = Color(0.55, 0.62, 0.72, 0.58) if reveal_quarter > 0 else Color(0.85, 0.95, 1.0, 0.72)
	court_stage.add_child(court_image)
	place_court_cast(court_stage)
	var cutin := skill_cutin_banner()
	if cutin != null:
		if cutin.get_meta("skill_triggered", false):
			play_sfx("skill")
		cutin.modulate.a = 0.0
		court_stage.add_child(cutin)
		play_skill_cutin_motion(cutin)
	var timeline := VBoxContainer.new()
	timeline.custom_minimum_size = Vector2(156 if is_handheld() else 280, 0)
	timeline.add_theme_constant_override("separation", 6)
	var timeline_scroll := ScrollContainer.new()
	timeline_scroll.custom_minimum_size.x = 156 if is_handheld() else 280
	timeline_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_scroll.add_child(timeline)
	lower.add_child(timeline_scroll)
	if not is_handheld():
		timeline.add_child(label("本場", 16, TEXT, true))
		if reveal_quarter > 0:
			var story_i := reveal_quarter - 1
			if story_i >= 0 and story_i < quarter_stories.size():
				timeline.add_child(wrap_label(str(quarter_stories[story_i]), 18, GOLD, true))
			else:
				timeline.add_child(wrap_label(current_quarter_skill_line(), 18, GOLD, true))
		else:
			timeline.add_child(label("哨響，先發就位", 14, MUTED, true))
	for i in match_visible_period_count():
		var home_qs: Array = quarter_scores[0] if quarter_scores.size() >= 1 and quarter_scores[0] is Array else []
		var away_qs: Array = quarter_scores[1] if quarter_scores.size() >= 2 and quarter_scores[1] is Array else []
		var home_value := "–"
		var away_value := "–"
		if i < reveal_quarter and i < home_qs.size():
			home_value = str(home_qs[i])
		if i < reveal_quarter and i < away_qs.size():
			away_value = str(away_qs[i])
		if is_handheld():
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			row.add_child(label(period_label(i), 18, CYAN))
			row.add_child(label("%s : %s" % [home_value, away_value], 18, TEXT))
			timeline.add_child(row)
		else:
			timeline.add_child(quarter_row(period_label(i), home_value, away_value, i < reveal_quarter))
	if is_handheld():
		content.add_child(wrap_label(current_quarter_skill_line() if reveal_quarter > 0 else "哨響，先發就位", 18, GOLD))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	if is_handheld():
		pin_above_dock(content, actions)
	else:
		content.add_child(actions)
	if reveal_quarter < match_period_count():
		actions.add_child(action_button("略過", Color("254e6b"), func(): skip_match_presentation(), Vector2(120, 48)))
		actions.add_child(action_button("下一節", ORANGE, func(): advance_match_quarter(), Vector2(120, 48)))
		if match_defense_changed:
			actions.add_child(label("半場已處理", 14, CYAN, false, HORIZONTAL_ALIGNMENT_LEFT))
		elif match_defense_menu:
			actions.add_child(label("半場落後，選剩下兩節的戰術", 14, GOLD, false, HORIZONTAL_ALIGNMENT_LEFT))
		elif can_halftime_adjust():
			actions.add_child(action_button("半場落後 · 換戰術", CYAN, func():
				match_defense_menu = true
				show_match_presentation()
			, Vector2(200, 48)))
		else:
			actions.add_child(label("自動播出 · 只有半場落後能換戰術", 14, MUTED, false, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		actions.add_child(action_button("看結算", GREEN, func(): show_post_match(), Vector2(0, 52)))
	if match_defense_menu and can_halftime_adjust():
		content.add_child(label("前兩節保留。改進攻或防守後，後半場依新戰術重算。", 13, MUTED))
		content.add_child(label("進攻", 14, GOLD, true))
		var offenses := HBoxContainer.new()
		offenses.add_theme_constant_override("separation", 8)
		content.add_child(offenses)
		for item in tactic_catalog("offense"):
			if not (item is Dictionary):
				continue
			var play := str(item.get("id", ""))
			if not tactic_unlocked_now(play, true):
				continue
			var pick := play
			var color := GOLD if pick == selected_tactic else ORANGE
			offenses.add_child(action_button(pick, color, func():
				selected_tactic = pick
				save_game()
				show_match_presentation()
			, Vector2(128, 42)))
		content.add_child(label("防守", 14, CYAN, true))
		var covers := HBoxContainer.new()
		covers.add_theme_constant_override("separation", 8)
		content.add_child(covers)
		for item in tactic_catalog("defense"):
			if not (item is Dictionary):
				continue
			var cover := str(item.get("id", ""))
			if not tactic_unlocked_now(cover, false):
				continue
			var pick_d := cover
			var dcolor := GOLD if pick_d == selected_defense else CYAN
			covers.add_child(action_button(pick_d, dcolor, func():
				selected_defense = pick_d
				save_game()
				show_match_presentation()
			, Vector2(128, 42)))
		content.add_child(gold_action_button("套用後半場戰術", func(): apply_halftime_tactics(), Vector2(0, 46)))
		content.add_child(action_button("不換，繼續打", Color("254e6b"), func():
			match_defense_menu = false
			match_defense_changed = true
			show_match_presentation()
		, Vector2(0, 46)))
	if OS.get_environment("TB_PLAYTEST") != "1" and not match_defense_menu:
		run_match_autoplay(ticket)

func run_match_autoplay(ticket: int) -> void:
	if can_halftime_adjust():
		return
	var delay := 1.0 if reveal_quarter == 0 else 3.0
	await get_tree().create_timer(delay, false).timeout
	if _app_suspended or ticket != match_play_id or not is_inside_tree() or current_stage != 6 or match_defense_menu:
		return
	advance_match_quarter()

func advance_match_quarter() -> void:
	match_play_id += 1
	if reveal_quarter == 2:
		match_defense_changed = true
		match_defense_menu = false
	if reveal_quarter < match_period_count():
		if quarter_scores.size() < 2 or not (quarter_scores[0] is Array) or not (quarter_scores[1] is Array) or quarter_scores[0].size() <= reveal_quarter or quarter_scores[1].size() <= reveal_quarter:
			show_post_match()
			return
		reveal_quarter += 1
		last_score[0] += int(quarter_scores[0][reveal_quarter - 1])
		last_score[1] += int(quarter_scores[1][reveal_quarter - 1])
		play_sfx("score")
		save_game()
		show_match_presentation()
	else:
		play_sfx("buzzer")
		show_post_match()

func skip_match_presentation() -> void:
	match_play_id += 1
	play_sfx("buzzer")
	while reveal_quarter < match_period_count():
		if quarter_scores.size() < 2 or not (quarter_scores[0] is Array) or not (quarter_scores[1] is Array) or quarter_scores[0].size() <= reveal_quarter or quarter_scores[1].size() <= reveal_quarter:
			break
		reveal_quarter += 1
		last_score[0] += int(quarter_scores[0][reveal_quarter - 1])
		last_score[1] += int(quarter_scores[1][reveal_quarter - 1])
	if reveal_quarter < match_period_count():
		match_rewards_pending = false
		show_dashboard()
		flash_notice("比賽資料不完整，未發放結算，請重新開打。")
		return
	show_post_match()

func place_court_cast(stage: Control) -> void:
	var spots := [Vector2(0.16, 0.62), Vector2(0.30, 0.36), Vector2(0.46, 0.24), Vector2(0.62, 0.38), Vector2(0.74, 0.60)]
	var rim := Vector2(0.86, 0.40)
	var active := active_match_players(maxi(0, reveal_quarter - 1))
	for i in mini(active.size(), spots.size()):
		var chip := simple_bust(active[i], 56)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.set_meta("court_from", spots[i])
		chip.set_meta("court_rim", rim if i == 0 else spots[i].lerp(Vector2(0.68, spots[i].y), 0.25))
		chip.set_meta("court_delay", 0.08 * float(i))
		stage.add_child(chip)
	call_deferred("run_court_motion", weakref(stage))

func run_court_motion(stage_ref: WeakRef) -> void:
	var stage := stage_ref.get_ref() as Control
	if not is_instance_valid(stage) or not stage.is_inside_tree():
		return
	for child in stage.get_children():
		if not (child is Control) or not child.has_meta("court_from"):
			continue
		var chip: Control = child
		var from_frac: Vector2 = chip.get_meta("court_from")
		var rim_frac: Vector2 = chip.get_meta("court_rim")
		var delay := float(chip.get_meta("court_delay"))
		drive_to_rim(chip, stage, from_frac, rim_frac, delay)

func drive_to_rim(chip: Control, stage: Control, from_frac: Vector2, rim_frac: Vector2, delay: float) -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(chip) or not chip.is_inside_tree() or not is_instance_valid(stage):
		return
	var limit := (stage.size - chip.size).max(Vector2.ZERO)
	var start := (stage.size * from_frac - chip.size * 0.5).clamp(Vector2.ZERO, limit)
	var rim := (stage.size * rim_frac - chip.size * 0.5).clamp(Vector2.ZERO, limit)
	chip.position = start
	chip.pivot_offset = chip.size * 0.5
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or not is_instance_valid(chip) or not chip.is_inside_tree():
		return
	var tw := chip.create_tween()
	tw.set_loops(2)
	tw.tween_property(chip, "position", rim, 0.58).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(chip, "scale", Vector2(0.96, 0.96), 0.08)
	tw.tween_property(chip, "scale", Vector2.ONE, 0.08)
	tw.tween_property(chip, "position", start, 0.42).set_trans(Tween.TRANS_SINE)

func skill_cutin_banner() -> Control:
	if reveal_quarter <= 0:
		return null
	var cutins: Dictionary = current_skill_modifiers.get("cutins", {}) if current_skill_modifiers.get("cutins", {}) is Dictionary else {}
	var raw_event = cutins.get(str(reveal_quarter), {})
	var event: Dictionary = raw_event if raw_event is Dictionary else {}
	var line := "膠著纏鬥"
	var title := "Q%d" % reveal_quarter
	var face: Dictionary = {}
	if not event.is_empty():
		title = str(event.get("name", "技能"))
		line = str(event.get("player", "球員"))
		var raw_face = event.get("player_data", {})
		face = raw_face if raw_face is Dictionary else {}
	if face.is_empty() and not team_players.is_empty():
		face = team_players[0]
		if title.begins_with("Q"):
			title = "關鍵回合"
			line = str(face.get("name", "先發"))
	var banner := Control.new()
	banner.set_meta("skill_triggered", not event.is_empty())
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.08, 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(dim)
	var card_h := 132 if is_handheld() else 210
	var card_w := int(round(float(card_h) * 603.0 / 900.0))
	var stage := Control.new()
	stage.name = "CutinStage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.custom_minimum_size = Vector2(card_w, card_h)
	stage.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	stage.anchor_left = 1.0
	stage.anchor_top = 0.5
	stage.anchor_right = 1.0
	stage.anchor_bottom = 0.5
	stage.offset_left = -card_w - 28
	stage.offset_top = -card_h * 0.52
	stage.offset_right = -28
	stage.offset_bottom = card_h * 0.48
	stage.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	banner.add_child(stage)
	var portrait := skill_cutin_portrait(face, Vector2(card_w, card_h))
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(portrait)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	words.anchor_top = 1.0
	words.offset_left = 18
	words.offset_right = -card_w - 40
	words.offset_top = -92
	words.offset_bottom = -16
	words.add_theme_constant_override("separation", 2)
	banner.add_child(words)
	words.add_child(label("技能觸發" if not event.is_empty() else "本節焦點", 18, GOLD, true, HORIZONTAL_ALIGNMENT_LEFT))
	words.add_child(wrap_label(title, 22, TEXT, true))
	if portrait.get_meta("used_nameplate", false) != true:
		words.add_child(wrap_label(line, 18, ORANGE_2, true))
	return banner

func play_skill_cutin_motion(banner: Control) -> void:
	if banner == null or not banner.is_inside_tree():
		return
	var stage := banner.get_node_or_null("CutinStage") as Control
	banner.modulate.a = 0.0
	if stage != null:
		stage.scale = Vector2(0.94, 0.94)
	var tw := banner.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(banner, "modulate:a", 1.0, 0.18)
	if stage != null:
		tw.parallel().tween_property(stage, "scale", Vector2.ONE, 0.24)

func skill_cutin_portrait(player: Dictionary, box: Vector2) -> Control:
	var host := Control.new()
	host.custom_minimum_size = box
	host.size = box
	host.clip_contents = false
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := ColorRect.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.color = Color(0.04, 0.06, 0.10, 1)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(plate)
	var tex: Texture2D = blended_card_portrait(player) if not player.is_empty() else null
	if tex == null and not player.is_empty():
		tex = bust_texture(player)
	if tex != null:
		var photo := TextureRect.new()
		photo.anchor_left = 0.27
		photo.anchor_right = 0.73
		photo.anchor_top = 0.18
		photo.anchor_bottom = 0.70
		photo.offset_left = 0.0
		photo.offset_right = 0.0
		photo.offset_top = 0.0
		photo.offset_bottom = 0.0
		photo.texture = tex
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(photo)
	elif not player.is_empty():
		var mark := VBoxContainer.new()
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		mark.anchor_left = 0.18
		mark.anchor_right = 0.82
		mark.anchor_top = 0.28
		mark.anchor_bottom = 0.68
		mark.alignment = BoxContainer.ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(mark)
		mark.add_child(plain_label(str(player.get("pos", "G")), 18, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
		mark.add_child(plain_label(str(player.get("name", "球員")), 16, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
		host.set_meta("used_nameplate", true)
	var cutin_tex := load_png_tex("res://assets/ui/hud/skill_cutin.png")
	if cutin_tex != null:
		var frame := TextureRect.new()
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.texture = cutin_tex
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(frame)
	return host

func reset_match_gain() -> void:
	last_match_gain = {"won": false, "gold": 0, "scout": 0, "cap": 0, "train": 0, "extra": false, "note": ""}

func last_gain_body() -> String:
	var budget_n := int(last_match_gain.get("budget", 0))
	if bool(last_match_gain.get("extra", false)):
		var prize := str(last_match_gain.get("note", "")).strip_edges()
		if budget_n > 0:
			return "資金 +$%d 萬" % budget_n + ("\n" + prize if not prize.is_empty() and prize != "本場沒有獲得" else "")
		if prize.is_empty():
			return "本場沒有獲得"
		return prize
	var gold_n := int(last_match_gain.get("gold", 0))
	var scout_n := int(last_match_gain.get("scout", 0))
	var cap_n := int(last_match_gain.get("cap", 0))
	var train_n := int(last_match_gain.get("train", 0))
	if not bool(last_match_gain.get("won", false)):
		return ("資金 +$%d 萬　·　" % budget_n if budget_n > 0 else "") + "黃金 +0　·　球探 +0"
	var lines := PackedStringArray()
	if budget_n > 0:
		lines.append("資金 +$%d 萬" % budget_n)
	lines.append("黃金 +%d" % gold_n)
	lines.append("球探 +%d" % scout_n)
	if cap_n != 0:
		lines.append("薪資帽 +$%d 萬" % cap_n)
	if train_n != 0:
		lines.append("特訓 +%d" % train_n)
	return "　·　".join(lines)

func last_gain_footer() -> String:
	return ""

func match_reason_summary(won: bool) -> String:
	# Keep the explanation grounded in values already produced by the simulator.
	# This is intentionally short enough for a phone result card.
	var own_ovr := roundi(average_ovr())
	var opp_ovr := int(last_opponent.get("rating", own_ovr)) if not last_opponent.is_empty() else own_ovr
	var parts: Array[String] = []
	if own_ovr != opp_ovr:
		parts.append("戰力 %s%d OVR" % ["+" if own_ovr > opp_ovr else "", own_ovr - opp_ovr])
	if match_threes.size() >= 2 and int(match_threes[0]) != int(match_threes[1]):
		parts.append("三分 %d－%d" % [int(match_threes[0]), int(match_threes[1])])
	var mismatch := lineup_mismatch_count()
	if mismatch > 0:
		parts.append("錯位 %d 人 -5 OVR" % mismatch)
	if not last_skill_event.is_empty() and last_skill_event != "尚未觸發特殊技能":
		parts.append("技能：%s" % last_skill_event)
	if parts.is_empty():
		parts.append("攻守與替補輪替共同決定比分")
	var lead := "取勝關鍵" if won else "落敗主因"
	return "%s：%s。" % [lead, "、".join(parts.slice(0, 3))]

func match_transparency_detail(won: bool) -> String:
	# Post-match audit card: every line comes from the same values shown in the
	# box score, so players can understand the result without guessing.
	var starter_pts := 0
	var bench_pts := 0
	var rebounds := 0
	var assists := 0
	for line in last_box_sheet:
		if not (line is Dictionary):
			continue
		var pts := int(line.get("pts", 0))
		if bool(line.get("starter", false)):
			starter_pts += pts
		else:
			bench_pts += pts
		rebounds += int(line.get("reb", 0))
		assists += int(line.get("ast", 0))
	var quarters := period_score_summary() if quarter_scores.size() >= 2 and quarter_scores[0] is Array and quarter_scores[0].size() >= 4 else "逐節資料尚未完成"
	var skills: Array = current_skill_modifiers.get("names", [])
	var skill_line := "未觸發已解鎖技能" if not (skills is Array and not skills.is_empty()) else "觸發：" + "、".join(skills)
	return "%s\n先發 %d 分 · 替補 %d 分\n籃板 %d · 助攻 %d\n%s\n%s" % [
		match_reason_summary(won), starter_pts, bench_pts, rebounds, assists, quarters, skill_line]

func pregame_factor_summary(opponent: Dictionary) -> String:
	var own := roundi(average_ovr())
	var theirs := int(opponent.get("rating", 70))
	var edge := own - theirs
	var line := "戰力：我方 %d OVR／對方 %d OVR（%s%d）" % [own, theirs, "+" if edge >= 0 else "", edge]
	var mismatch := lineup_mismatch_count()
	if mismatch > 0:
		line += "\n錯位：%d 人，每人 -5 OVR" % mismatch
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	line += "\n戰術：我方 %s／%s · 對方 %s／%s" % [selected_tactic, selected_defense, style.get("offense", "半場傳導"), style.get("defense", "人盯人")]
	line += "\n外援：%d／%d · 名單：%d 人" % [foreigner_count(), foreigner_limit(), team_players.size()]
	return line

func show_post_match() -> void:
	if match_rewards_pending and reveal_quarter >= match_period_count() and last_score[0] == last_score[1]:
		var overtime_rng := RandomNumberGenerator.new()
		overtime_rng.seed = randi()
		while _quarter_sum(0, quarter_scores[0].size()) == _quarter_sum(1, quarter_scores[1].size()):
			roll_one_period(quarter_scores[0].size(), overtime_rng)
		save_game()
	if match_rewards_pending and reveal_quarter < match_period_count():
		skip_match_presentation()
		return
	# Signed-in players must receive the authoritative economy result before the
	# local result screen applies any rewards. Offline play keeps its existing
	# local path, but never mixes a local grant into a cloud account.
	if match_rewards_pending and not server_settlement_ready and not auth_access.is_empty():
		if not server_settlement_inflight:
			request_server_match_settlement()
		return
	server_settlement_ready = false
	active_menu = "result"
	var won := last_score[0] > last_score[1]
	var extra_just := extra_match if match_rewards_pending else bool(last_match_gain.get("extra", false))
	var extra_event_id := extra_event if match_rewards_pending else str(last_match_gain.get("event_id", extra_event))
	var settling := match_rewards_pending
	_settling_match = settling
	if settling:
		resolve_prediction(won)
	if settling and not extra_just:
		record_match_appearances()
	if match_rewards_pending and extra_just:
		finish_extra_match(won)
	elif match_rewards_pending:
		var budget_before_reward := budget_million
		var budget_gain := match_budget_reward(won)
		budget_million += budget_gain
		var was_regular := season_phase == "regular"
		season_games += 1
		if season_phase == "regular":
			regular_games += 1
			if won:
				regular_wins += 1
			else:
				regular_losses += 1
			check_veteran_missions(won)
		else:
			check_veteran_missions(won)
		if won:
			season_wins += 1
			win_streak += 1
			var gold_gain := apply_win_streak(randi_range(5, 10))
			var scout_gain := apply_win_streak(randi_range(1, 3))
			var cap_gain := apply_win_streak(WIN_CAP_GAIN)
			salary_cap_bonus += cap_gain
			apply_salary_cap()
			gold += gold_gain
			chemistry = mini(100, chemistry + 4)
			scout_points += scout_gain
			training_points += 1
			var streak_note := ""
			if win_streak >= 3:
				streak_note = "連勝 %d（+%d%%）。" % [win_streak, int(win_streak_rate() * 100.0)]
			else:
				streak_note = "連勝 %d。" % win_streak
			last_event = "勝利。%s資金 +$%d 萬、薪資帽 +$%d 萬、黃金 +%d、球探 +%d、特訓 +1。" % [streak_note, budget_gain, cap_gain, gold_gain, scout_gain]
			last_match_gain = {"won": true, "budget": budget_gain, "gold": gold_gain, "scout": scout_gain, "cap": cap_gain, "train": 1, "extra": false, "note": streak_note}
			last_progress_event = "三分 %d-%d · %s" % [match_threes[0], match_threes[1], last_tactic_report]
		else:
			season_losses += 1
			win_streak = 0
			chemistry = maxi(20, chemistry - 2)
			last_event = "惜敗。資金 +$%d 萬；黃金與球探點 +0。對手是 %s。" % [budget_gain, last_opponent.get("name", "對手")]
			last_match_gain = {"won": false, "budget": budget_gain, "gold": 0, "scout": 0, "cap": 0, "train": 0, "extra": false, "note": ""}
			last_progress_event = "三分 %d-%d · %s" % [match_threes[0], match_threes[1], last_tactic_report]
		generate_box_sheet(int(last_score[0]))
		if was_regular:
			record_result(club_team_id(), int(last_score[0]), int(last_score[1]), won)
			var opp_id := str(last_opponent.get("team_id", last_opponent.get("id", "")))
			if not opp_id.is_empty():
				record_result(opp_id, int(last_score[1]), int(last_score[0]), not won)
			simmer_other_games()
		advance_season_after_match(won)
		apply_match_challenge(won, budget_before_reward)
		if was_regular and season_phase == "regular" and season_games > 0 and season_games < regular_season_length():
			advance_fixture()
		var result_word := "贏了" if won else "輸給"
		var line := "%s%s" % [result_word, last_opponent.get("name", "對手")]
		if last_home_points > 0:
			line += "。主場提供戰力加成，不是固定加分"
		var nxt := next_fixture_line()
		if not nxt.is_empty():
			line += "，%s" % nxt.replace("再下一場 ", "下週").replace("下一場 ", "下週")
		line += "。"
		push_news(line)
		last_match_played = true
		track_event("match_completed", {"won": won, "league": current_league, "score_for": int(last_score[0]), "score_against": int(last_score[1]), "extra": extra_just})
		match_rewards_pending = false
	if settling and not server_settlement_balance.is_empty():
		# The server balance is authoritative. Local match stats and presentation
		# remain local, while all four economy values are replaced atomically.
		budget_million = int(server_settlement_balance.get("budget_million", budget_million))
		gold = int(server_settlement_balance.get("gold", gold))
		scout_points = int(server_settlement_balance.get("scout_points", scout_points))
		training_points = int(server_settlement_balance.get("training_points", training_points))
	_settling_match = false
	if settling:
		save_game()
	var content := begin_screen("額外比賽結算" if extra_just else "結算", str(extra_event_data(extra_event_id).get("title", "額外比賽")) if extra_just else "%s · 例行賽 %d-%d" % [season_phase_label(), regular_wins, regular_losses], 4)
	if is_handheld():
		content.add_theme_constant_override("separation", 8)
	var result := PanelContainer.new()
	result.custom_minimum_size = Vector2(0, 92 if is_handheld() else 148)
	result.add_theme_stylebox_override("panel", panel_style(Color("131c29f5"), GREEN if won else RED, 24, 2))
	content.add_child(result)
	var result_row := HBoxContainer.new()
	result_row.alignment = BoxContainer.ALIGNMENT_CENTER
	result_row.add_theme_constant_override("separation", 30)
	result.add_child(padded(result_row, 8 if is_handheld() else 18))
	result_row.add_child(team_score(club_display_name(), str(last_score[0]), ORANGE))
	var badge := VBoxContainer.new()
	badge.custom_minimum_size = Vector2(220, 0)
	badge.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_child(label("勝利" if won else "惜敗", 30 if is_handheld() else 38, GREEN if won else RED, true, HORIZONTAL_ALIGNMENT_CENTER))
	if extra_just:
		badge.add_child(label(extra_record_line(extra_event_id), 14, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		badge.add_child(label("戰績 %d - %d" % [season_wins, season_losses], 14, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	result_row.add_child(badge)
	result_row.add_child(team_score(str(last_opponent.get("name", "對手")), str(last_score[1]), CYAN))

	var analysis := HBoxContainer.new()
	analysis.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	analysis.add_theme_constant_override("separation", 10)
	content.add_child(analysis)
	analysis.add_child(mvp_result_card())
	analysis.add_child(match_info("勝負關鍵", match_transparency_detail(won), "可在賽前調整位置、戰術與替補", ORANGE if won else RED))
	var qtext := "尚無逐節紀錄"
	if quarter_scores.size() >= 2 and quarter_scores[0] is Array and quarter_scores[1] is Array and quarter_scores[0].size() >= 4 and quarter_scores[1].size() >= 4:
		qtext = period_score_summary()
	analysis.add_child(match_info("本場收穫", last_gain_body(), last_gain_footer(), GREEN))
	var details := VBoxContainer.new()
	details.name = "ResultDetails"
	details.add_theme_constant_override("separation", 10)
	details.visible = not is_handheld()
	var detail_actions := HBoxContainer.new()
	detail_actions.add_theme_constant_override("separation", 10)
	content.add_child(detail_actions)
	detail_actions.add_child(action_button("球員數據", Color("254e6b"), func(): show_box_score_sheet()))
	var toggle := action_button("收起分析" if details.visible else "展開比賽分析", Color("254e6b"), func(): pass)
	toggle.name = "ResultDetailsToggle"
	toggle.pressed.connect(func():
		details.visible = not details.visible
		toggle.text = "收起分析" if details.visible else "展開比賽分析"
	)
	detail_actions.add_child(toggle)
	if not extra_just and not playoff_state.is_empty():
		detail_actions.add_child(action_button("系列賽對戰表", CYAN, show_playoff_bracket))
	content.add_child(details)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 10)
	details.add_child(detail_row)
	detail_row.add_child(match_info("各節比分", qtext, "三分 %d - %d" % [match_threes[0], match_threes[1]], CYAN))
	detail_row.add_child(match_info("戰術", last_tactic_report, last_match_venue_line(), ORANGE))
	details.add_child(label("數據王 · " + kings_summary_line(), 14, MUTED))
	if trade_notice_pending:
		content.add_child(callout("交易已生效", "換人只改你的名單。對手本場仍用原陣容，所以比分不會因為交易變臉。", GOLD))
		trade_notice_pending = false
	if extra_just:
		detail_actions.add_child(action_button("回額外比賽", ORANGE, func():
			if extra_event_id.is_empty():
				show_extra_events()
			else:
				show_extra_event(extra_event_id)
		, Vector2(0, 58)))
		maybe_play_card_reveal()
		return
	var next_label := "回大廳看下一場"
	if season_phase == "champion":
		next_label = "看獎盃"
	elif season_phase == "offseason":
		next_label = "進入休賽季"
	elif season_phase == "final":
		next_label = "準備冠軍戰"
	elif season_phase == "semifinal":
		next_label = "準備下一場系列賽"
	detail_actions.add_child(action_button(next_label, ORANGE, func():
		if season_phase == "champion":
			show_trophy()
		elif season_phase == "offseason":
			show_offseason()
		else:
			show_dashboard()
	, Vector2(0, 58)))

func box_score_row(line: Dictionary) -> PanelContainer:
	var starter := bool(line.get("starter", false))
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	row.add_theme_stylebox_override("panel", panel_style(Color("0d1c2bed"), (GOLD if starter else CYAN).darkened(0.45), 10, 1))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(padded(box, 7))
	box.add_child(plain_label(str(line.get("pos", "G")), 12, CYAN, true))
	var who := plain_label(str(line.get("name", "球員")), 13, TEXT, true)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(who)
	box.add_child(plain_label("%d′" % int(line.get("min", 0)), 12, MUTED, true))
	box.add_child(plain_label("%d 分" % int(line.get("pts", 0)), 13, GOLD, true))
	box.add_child(plain_label("%d 籃" % int(line.get("reb", 0)), 12, MUTED, true))
	box.add_child(plain_label("%d 助" % int(line.get("ast", 0)), 12, MUTED, true))
	return row

func show_box_score_sheet() -> void:
	close_guide_modal()
	if last_box_sheet.is_empty():
		flash_notice("這場還沒有數據")
		return
	var veil := ColorRect.new()
	guide_modal = veil
	veil.name = "GuideModal"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.03, 0.05, 0.72)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 50
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var sheet := PanelContainer.new()
	var view := get_viewport_rect().size
	sheet.custom_minimum_size = Vector2(mini(view.x - 72.0, 920.0), mini(view.y - 88.0, 420.0))
	sheet.add_theme_stylebox_override("panel", panel_style(Color("0c1927fc"), GOLD, 18, 2))
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	sheet.add_child(padded(box, 12))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var title_lab := label("本場數據", 18, GOLD, true)
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	head.add_child(plain_label("上場分鐘 · 分／籃／助", 12, MUTED, true))
	var close := action_button("關閉", Color("27394a"), func(): close_guide_modal(), Vector2(72, 40))
	close.add_theme_font_size_override("font_size", 13)
	head.add_child(close)
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	box.add_child(cols)
	cols.add_child(box_score_column("先發", true, GOLD))
	cols.add_child(box_score_column("替補", false, CYAN))

func box_score_column(title: String, starters: bool, accent: Color) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	col.add_child(plain_label(title, 14, accent, true))
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 12 if is_handheld() else 0
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	bind_scroll_child_width(scroll, list)
	var shown := 0
	for line in last_box_sheet:
		if not (line is Dictionary):
			continue
		if bool(line.get("starter", false)) != starters:
			continue
		list.add_child(box_score_row(line))
		shown += 1
	if shown == 0:
		list.add_child(plain_label("這場沒有替補上場" if not starters else "沒有先發數據", 13, MUTED, true))
	return col

func apply_match_challenge(won: bool, _budget_before_reward: int) -> void:
	if active_challenge.is_empty() or not won:
		return
	maybe_trigger_challenge_incident()
	if active_challenge == "small_market" and average_ovr() <= 77.0:
		challenge_progress["small_market"] = mini(challenge_target("small_market"), int(challenge_progress.get("small_market", 0)) + 1)
		last_progress_event = "小市場重建進度：%s" % challenge_progress_text("small_market")
		if int(challenge_progress.get("small_market", 0)) >= challenge_target("small_market"):
			complete_active_challenge("small_market")
	elif active_challenge == "salary_cap" and roster_salary() <= 650:
		challenge_progress["salary_cap"] = 1
		complete_active_challenge("salary_cap")

func complete_active_challenge(challenge_id: String) -> void:
	if bool(challenge_completed.get(challenge_id, false)):
		return
	challenge_completed[challenge_id] = true
	mission_alert = true
	active_challenge = ""
	var scout_reward := 4 if challenge_id != "salary_cap" else 3
	var salary_reward := 120 if challenge_id == "small_market" else (180 if challenge_id == "salary_cap" else 250)
	scout_points += scout_reward
	budget_million += salary_reward
	last_progress_event = "挑戰完成：%s。資金 +$%d 萬、球探點 +%d。" % [challenge_label(challenge_id), salary_reward, scout_reward]
	last_news = last_progress_event
	call_deferred("flash_notice", "任務完成！%s　獎勵已發放，任務圖示會顯示驚嘆號。" % challenge_label(challenge_id))

func reset_regular_season() -> void:
	season_games = 0
	season_wins = 0
	season_losses = 0
	regular_games = 0
	regular_wins = 0
	regular_losses = 0
	opponent_index = 0
	schedule_index = 0

func check_veteran_missions(won: bool) -> void:
	if team_players.is_empty():
		return
	var origin := origin_id(team_players[0])
	if str(veteran_mission.get("origin", "")) != origin:
		veteran_mission = {"origin": origin, "games": 0, "wins": 0, "stage": int(veteran_mission.get("stage", 0))}
	veteran_mission["games"] = int(veteran_mission.get("games", 0)) + 1
	if won:
		veteran_mission["wins"] = int(veteran_mission.get("wins", 0)) + 1
	var stage := int(veteran_mission.get("stage", 0))
	if stage < 1 and int(veteran_mission.get("games", 0)) >= 4:
		veteran_mission["stage"] = 1
		last_event += " 隱藏任務 1/3：班底磨合中。"
	if stage < 2 and int(veteran_mission.get("wins", 0)) >= 6:
		veteran_mission["stage"] = 2
		last_event += " 隱藏任務 2/3：老將開始注意你。"
	if int(veteran_mission.get("stage", 0)) >= 2 and (not combo_state().is_empty() or season_phase != "regular"):
		var unlocked_any := false
		for raw in all_league_players():
			if not is_veteran_player(raw):
				continue
			if origin_id(raw) != origin:
				continue
			var pid := str(raw.get("id", raw.get("name", "")))
			if veteran_cleared.has(pid):
				continue
			veteran_cleared.append(pid)
			unlocked_any = true
			last_event += " 隱藏任務完成：可邀請老將 %s。" % raw.get("name", "球員")
			break
		if unlocked_any:
			veteran_mission["stage"] = 3

func advance_season_after_match(_won: bool) -> void:
	refresh_tactic_unlocks()
	if current_league in ["EASL", "BCL"]:
		if season_games >= regular_season_length():
			open_offseason("國際賽結束，可準備下一季。")
		return
	if season_phase == "regular":
		if regular_games >= regular_season_length():
			capture_draft_order()
			mark_pro_top2_if_earned()
			create_playoffs()
		return
	if season_phase in ["playin", "semifinal", "final"]:
		ensure_legacy_playoffs()
		var s := PlayoffSeries.user_series(playoff_state)
		if s.is_empty():
			return
		var high := str(s.a.team_id) == club_team_id()
		if PlayoffSeries.record(s, int(last_score[0] if high else last_score[1]), int(last_score[1] if high else last_score[0])):
			series_opponent_adjustment(s)
			advance_playoff_bracket()

func unlock_after_title() -> void:
	if current_league == "SBL":
		pending_path = "pro"
		last_event += " 選 PLG 或 TPBL 進入下一階，第一次升上職業不加難。"
	elif current_league == "PLG" or current_league == "TPBL":
		var other := "TPBL" if current_league == "PLG" else "PLG"
		if not unlocked_leagues.has(other):
			unlocked_leagues.append(other)
		last_event += " 可換 %s 或打下一季，難度會提高。東超需前二資格＋通行證。" % other

func enter_league(code: String) -> void:
	start_next_season(code, false)

func show_trophy() -> void:
	var content := begin_screen("冠軍", "%s · %s" % [club_name, current_league], 4)
	content.add_child(callout("獎盃", "SBL 冠軍後選 PLG 或 TPBL。職業前二才有東超資格。東超／BCL 是 3 場國際賽，需 NT$100 通行證。", GOLD))
	var strip := card_strip()
	content.add_child(strip)
	for i in mini(team_players.size(), 5):
		var who: Dictionary = team_players[i]
		var card := player_show_card(who, str(who.get("pos", "G")), "冠軍班底", GOLD, i == 0, func():
			show_player_sheet(who, func(): show_trophy())
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	if pending_path == "pro":
		content.add_child(callout("選路", "選一條職業聯盟開打。第一次升上不加難。另一條等你打完這一階再解鎖。", ORANGE))
		row.add_child(action_button("去 PLG", ORANGE, func(): start_next_season("PLG", false), Vector2(0, 50)))
		row.add_child(action_button("去 TPBL", CYAN, func(): start_next_season("TPBL", false), Vector2(0, 50)))
	else:
		row.add_child(action_button("進入休賽季", GOLD, func():
			open_offseason("%s 冠軍之後。選下一季或換聯盟，難度會提高。" % current_league)
			show_offseason()
		, Vector2(0, 50)))
		row.add_child(action_button("去東超", GOLD, func(): try_enter_international("EASL"), Vector2(0, 50)))
		row.add_child(action_button("去 BCL", RED, func(): try_enter_international("BCL"), Vector2(0, 50)))
	content.add_child(action_button("回大廳", Color("254e6b"), func(): show_dashboard(), Vector2(0, 48)))

func gold_scout_pull() -> void:
	if card_inventory.size() >= vault_capacity():
		flash_notice("保管箱已滿（%d／%d），沒有扣除黃金" % [card_inventory.size(), vault_capacity()])
		return
	if gold < 80:
		flash_notice("黃金不足：卡包要 80。黃金不能拿去墊薪資。")
		return
	gold -= 80
	var fresh: Array[Dictionary] = []
	for raw in public_players:
		var card := to_game_player(raw)
		if is_veteran_player(card) and not veteran_unlocked(card):
			continue
		if is_locked_prize(card):
			continue
		fresh.append(card)
	if fresh.is_empty():
		gold += 80
		flash_notice("沒有還沒擁有的球員可抽")
		return
	fresh.shuffle()
	var pulled: Dictionary = fresh[0]
	gacha_opened += 1
	var duplicate := team_has_player(pulled)
	pulled["duplicate_pull"] = duplicate
	card_inventory.append(pulled)
	if duplicate:
		last_event = "黃金卡包開出重複卡 %s，已加入保管箱。" % pulled.get("name", "球員")
		duplicate_notices.append("%s → 重複卡已加入保管箱" % pulled.get("name", "球員"))
		call_deferred("show_duplicate_notice")
		save_game()
		show_pack_result(pulled, 0)
		queue_purchase_success("黃金卡包", "已使用 80 黃金；%s 是重複卡，已放入保管箱" % str(pulled.get("name", "球員")))
		return
	last_event = "黃金卡包開出 %s（OVR %d）。可放進先發或留在保管箱。" % [pulled.get("name", "球員"), pulled.get("ovr", 70)]
	save_game()
	show_pack_result(pulled)
	show_card_reveal(pulled, func():
		show_purchase_success("黃金卡包", "已使用 80 黃金並取得 %s" % str(pulled.get("name", "球員")))
	)

func show_pack_result(pulled: Dictionary, duplicate_gold := 0) -> void:
	var content := begin_screen("卡包", "花 80 黃金抽一張。卡包只在商店，跟球探點分開。", 4)
	if bool(pulled.get("duplicate_pull", false)):
		content.add_child(callout("重複卡已收錄", "%s 已在名單或保管箱，本張仍保留並加入保管箱，可作收藏或日後替換。" % str(pulled.get("name", "球員")), GOLD))
	var card := player_show_card(pulled, "卡包", weekly_stat_line(pulled), ovr_frame_color(int(pulled.get("ovr", 70))), true, func():
		if duplicate_gold > 0:
			show_player_sheet(pulled, func(): show_pack_result(pulled, duplicate_gold))
		else:
			show_player_sheet(pulled, func(): show_pack_result(pulled), func(): place_inventory_card(card_inventory.size() - 1), "放入先發")
	)
	card.custom_minimum_size = Vector2(280, 320)
	content.add_child(card)
	if duplicate_gold <= 0:
		content.add_child(action_button("放入先發", ORANGE, func(): place_inventory_card(card_inventory.size() - 1), Vector2(0, 52)))
		content.add_child(action_button("留在保管箱", Color("254e6b"), func(): show_store_hub(), Vector2(0, 48)))
	else:
		content.add_child(action_button("回商店", Color("254e6b"), func(): show_store_hub(), Vector2(0, 48)))

func place_inventory_card(index: int) -> void:
	if index < 0 or index >= card_inventory.size():
		return
	var raw: Dictionary = card_inventory[index]
	if roster_has_player(raw):
		flash_notice("這名球員已經在名單裡，不能放第二張")
		return
	var block := can_sign_player(raw, true)
	if not block.is_empty():
		flash_notice(block)
		return
	var player := to_game_player(raw)
	card_inventory.remove_at(index)
	# 登錄保管箱卡只加入名單，不重建 5 人先發，避免替補被自動換掉或遺失。
	team_players.append(player)
	apply_combo_label()
	last_event = "%s 登錄球隊。" % player.get("name", "球員")
	save_game()
	show_roster()

func show_coach_market() -> void:
	active_menu = "market"
	var content := begin_screen("教練", "教練吃薪資帽，也可以花黃金禮聘。影響今晚對位。", 4)
	content.add_child(label("現任：%s" % coach_data(coach_id).get("name", ""), 14, GOLD, true))
	for item in career_rules.get("coaches", []):
		if not (item is Dictionary):
			continue
		var cid := str(item.get("id", ""))
		var need := str(item.get("need", "SBL"))
		var owned := coaches_owned.has(cid)
		var note := str(item.get("blurb", ""))
		if not league_open(need) and need != "SBL":
			note = "需先解鎖 %s" % need
		content.add_child(hub_tile(str(item.get("name", "教練")), note, "使用中" if cid == coach_id else ("已擁有" if owned else "薪資 %d · 金 %d" % [int(item.get("cost_salary", 0)), int(item.get("cost_gold", 0))]), GREEN if cid == coach_id else ORANGE, func():
			hire_coach(cid)
		, {}))

func hire_coach(cid: String) -> void:
	var data := coach_data(cid)
	if data.is_empty():
		flash_notice("找不到這位教練")
		return
	var need := str(data.get("need", "SBL"))
	if need != "SBL" and not league_open(need):
		flash_notice("還沒解鎖 %s 教練市場" % need)
		return
	if roster_salary() - int(coach_data(coach_id).get("cost_salary", 0)) + int(data.get("cost_salary", 0)) > salary_cap:
		flash_notice("聘這位會超過薪資帽")
		return
	var newly_purchased := not coaches_owned.has(cid)
	var paid_gold := 0
	if newly_purchased:
		var pay_g := int(data.get("cost_gold", 0))
		if gold < pay_g:
			flash_notice("黃金不足")
			return
		gold -= pay_g
		paid_gold = pay_g
		coaches_owned.append(cid)
	coach_id = cid
	last_event = "教練換成 %s。%s" % [data.get("name", "教練"), data.get("blurb", "")]
	save_game()
	show_coach_market()
	if newly_purchased:
		queue_purchase_success(str(data.get("name", "教練")), "已使用 %d 黃金並設為現任教練" % paid_gold)

func show_synthesis() -> void:
	show_card_vault()
	flash_notice("沒有隨便三張合成。同一人只能一張，重複卡直接換黃金。")

func run_synthesis() -> void:
	show_synthesis()

func collect_match_state() -> Dictionary:
	return {
		"pending": match_rewards_pending,
		"quarter": reveal_quarter,
		"opponent": last_opponent,
		"extra": extra_match,
		"defense_changed": match_defense_changed,
		"defense_menu": match_defense_menu,
		"rotation": last_match_oncourt,
		"stories": quarter_stories,
		"threes": match_threes,
		"report": last_tactic_report,
		"events": match_event_log,
		"skill_modifiers": current_skill_modifiers,
	}

func restore_match_state(data: Dictionary) -> void:
	match_play_id += 1
	match_rewards_pending = false
	extra_match = false
	match_defense_menu = false
	match_defense_changed = false
	reveal_quarter = 0
	last_opponent = {}
	last_match_oncourt = []
	quarter_stories = []
	match_threes = [0, 0]
	last_tactic_report = ""
	match_event_log.clear()
	current_skill_modifiers.clear()
	var state: Variant = data.get("match_state", {})
	if not (state is Dictionary) or state.is_empty():
		return # Version 3 did not persist a resumable match.
	if state.get("opponent") is Dictionary:
		last_opponent = apply_opponent_ovr_bonus(state.opponent.duplicate(true))
	if state.get("rotation") is Array:
		last_match_oncourt = state.rotation.duplicate(true)
	if state.get("stories") is Array:
		quarter_stories = state.stories.duplicate()
	if state.get("threes") is Array and state.threes.size() == 2:
		match_threes = [int(state.threes[0]), int(state.threes[1])]
	last_tactic_report = str(state.get("report", ""))
	if state.get("events") is Array:
		for event in state.events:
			match_event_log.append(str(event))
	if state.get("skill_modifiers") is Dictionary:
		current_skill_modifiers = state.skill_modifiers.duplicate(true)
	if not bool(state.get("pending", false)):
		return
	if quarter_scores.size() != 2 or last_opponent.is_empty():
		return
	for scores in quarter_scores:
		if not (scores is Array) or scores.size() < 4 or scores.size() > 64 or scores.size() != quarter_scores[0].size():
			return
		for score in scores:
			if not (score is int or score is float) or score < 0 or score > 100:
				return
	reveal_quarter = clampi(int(state.get("quarter", 0)), 0, match_period_count())
	# Derive the visible total; never reward a partial or stale saved score.
	last_score = [0, 0]
	for q in reveal_quarter:
		last_score[0] += int(quarter_scores[0][q])
		last_score[1] += int(quarter_scores[1][q])
	match_rewards_pending = true
	extra_match = bool(state.get("extra", false))
	match_defense_changed = bool(state.get("defense_changed", false))
	match_defense_menu = bool(state.get("defense_menu", false)) and can_halftime_adjust()

func collect_save_data() -> Dictionary:
	if team_profiles.size() < MAX_TEAM_PROFILES:
		while team_profiles.size() < MAX_TEAM_PROFILES:
			team_profiles.append({})
	var data := {
		"playoff_state": playoff_state,
		"draft_state": draft_state,
		"drafted_prospect_ids": drafted_prospect_ids,
		"version": 4,
		"match_state": collect_match_state(),
		"club_name": club_name,
		"club_logo_id": ensure_club_logo_id(),
		"selected_foundation": selected_foundation,
		"selected_tactic": selected_tactic,
		"selected_defense": selected_defense,
		"is_home_game": is_home_game,
		"season_wins": season_wins,
		"season_losses": season_losses,
		"season_games": season_games,
		"chemistry": chemistry,
		"budget_million": budget_million,
		"economy_version": economy_version,
		"scout_points": scout_points,
		"scout_floor_game": scout_floor_game,
		"training_points": training_points,
		"opponent_index": opponent_index,
		"last_score": last_score,
		"last_mvp": last_mvp,
		"last_box": last_box,
		"last_event": last_event,
		"last_match_played": last_match_played,
		"quarter_scores": quarter_scores,
		"last_skill_event": last_skill_event,
		"last_news": last_news,
		"trade_notice_pending": trade_notice_pending,
		"gacha_opened": gacha_opened,
		"scout_pity_progress": scout_pity_progress,
		"scout_board_serial": scout_board_serial,
		"supporter_theme": supporter_theme,
		"store_cosmetics_owned": store_cosmetics_owned,
		"locker_room_theme": locker_room_theme,
		"vault_capacity_bonus": vault_capacity_bonus,
		"second_team_unlocked": second_team_unlocked,
		"active_challenge": active_challenge,
		"challenge_progress": challenge_progress,
		"challenge_completed": challenge_completed,
		"mission_alert": mission_alert,
		"daily_checkin_date": daily_checkin_date,
		"daily_checkin_streak": daily_checkin_streak,
		"daily_checkin_days": daily_checkin_days,
		"monthly_pass_active": monthly_pass_active,
		"monthly_pass_claimed_date": monthly_pass_claimed_date,
		"monthly_pass_claimed_days": monthly_pass_claimed_days,
		"scout_free_refresh_date": scout_free_refresh_date,
		"prediction_match_key": prediction_match_key,
		"prediction_pick": prediction_pick,
		"prediction_margin": prediction_margin,
		"prediction_stake": prediction_stake,
		"prediction_points": prediction_points,
		"prediction_correct": prediction_correct,
		"prediction_badges": prediction_badges,
		"equipped_badges": equipped_badges,
		"async_season_active": async_season_active,
		"async_season_game": async_season_game,
		"async_season_wins": async_season_wins,
		"async_season_losses": async_season_losses,
		"async_season_points": async_season_points,
		"async_season_roster_snapshot": async_season_roster_snapshot,
		"async_season_settled_key": async_season_settled_key,
		"last_progress_event": last_progress_event,
		"national_tournament": national_tournament,
		"national_roster": national_roster,
		"national_registered": national_registered,
		"national_games": national_games,
		"national_wins": national_wins,
		"national_last_result": national_last_result,
		"team_players": team_players,
		"active_team_index": active_team_index,
		"team_profiles": team_profiles,
		"gold": gold,
		"salary_cap": salary_cap,
		"salary_cap_bonus": salary_cap_bonus,
		"current_league": current_league,
		"unlocked_leagues": unlocked_leagues,
		"season_phase": season_phase,
		"championships": championships,
		"unlocked_offense": unlocked_offense,
		"unlocked_defense": unlocked_defense,
		"card_inventory": card_inventory,
		"veteran_cleared": veteran_cleared,
		"coach_id": coach_id,
		"coaches_owned": coaches_owned,
		"national_unlocked": national_unlocked,
		"combo_label": combo_label,
		"tutorial_seen": tutorial_seen,
		"save_slot": active_save_slot,
		"regular_wins": regular_wins,
		"regular_losses": regular_losses,
		"regular_games": regular_games,
		"veteran_mission": veteran_mission,
		"iap_national": national_unlocked,
		"season_schedule": season_schedule,
		"schedule_index": schedule_index,
		"news_feed": news_feed,
		"league_table": league_table,
		"closer_name": closer_name,
		"last_box_sheet": last_box_sheet,
		"last_match_gain": last_match_gain,
		"last_home_points": last_home_points,
		"pending_path": pending_path,
		"win_streak": win_streak,
		"gacha_candidates": gacha_candidates,
		"pro_top2": pro_top2,
		"difficulty_level": difficulty_level,
		"national_event": national_event,
		"national_progress": national_progress,
		"last_pro_league": last_pro_league,
		"easl_pass": easl_pass,
		"jones_pass": jones_pass,
		"extra_event": extra_event,
		"extra_entry": extra_entry,
		"extra_wins": extra_wins,
		"extra_queue": extra_queue,
		"extra_runs": extra_runs,
		"extra_champions": extra_champions,
	}
	team_profiles[active_team_index] = {"name": club_name, "logo_id": ensure_club_logo_id(), "players": team_players.duplicate(true), "career": TeamCareer.extract(data)}
	return data

func ensure_cloud() -> void:
	if is_instance_valid(cloud_http):
		return
	cloud_http = HTTPRequest.new()
	cloud_http.name = "CloudHttp"
	cloud_http.timeout = 25
	cloud_http.request_completed.connect(_on_cloud_http_for_generation.bind(cloud_generation))
	add_child(cloud_http)

func _on_cloud_http_for_generation(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, generation: int) -> void:
	if generation == cloud_generation:
		_on_cloud_http(result,code,headers,body)

func cloud_is_busy() -> bool:
	return is_instance_valid(cloud_http) and cloud_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED

func request_server_match_settlement() -> void:
	if auth_access.is_empty() or not match_rewards_pending:
		return
	server_settlement_inflight = true
	if server_settlement_match_id.is_empty():
		server_settlement_match_id = RankedRules.request_id()
	var body := JSON.stringify({
		"p_match_id": server_settlement_match_id,
		"p_won": last_score[0] > last_score[1],
		"p_league": "extra" if extra_match else current_league,
		# Kept for RPC backwards compatibility; the server deliberately ignores
		# these client supplied reward fields.
		"p_budget": 0,
		"p_gold": 0,
		"p_scout": 0,
		"p_training": 0,
	})
	cloud_send("settle_match", "%s/rest/v1/rpc/godot_match_settle" % SUPABASE_URL, supabase_headers(true), HTTPClient.METHOD_POST, body)

func show_settlement_retry_notice(message: String) -> void:
	# Never leave a signed-in match on the presentation screen with no action
	# after a timeout or malformed response. The match id is retained so retrying
	# remains idempotent and cannot grant rewards twice.
	show_guide_sheet("結算需要重試", message + "\n比賽結果已保留，獎勵在伺服器確認前不會重複發放。", GOLD, "重試結算", func():
		close_guide_modal()
		request_server_match_settlement()
	)

func request_server_economy_spend(action: String, delta_budget: int, delta_gold: int, delta_scout: int, delta_training: int, callback: Callable) -> void:
	if auth_access.is_empty() or server_spend_inflight:
		return
	server_spend_inflight = true
	server_spend_callback = callback
	server_spend_request_id = RankedRules.request_id()
	var body := JSON.stringify({
		"p_action": action,
		"p_request_id": server_spend_request_id,
		"p_delta_budget": delta_budget,
		"p_delta_gold": delta_gold,
		"p_delta_scout": delta_scout,
		"p_delta_training": delta_training,
	})
	cloud_send("economy_spend", "%s/rest/v1/rpc/godot_economy_apply" % SUPABASE_URL, supabase_headers(true), HTTPClient.METHOD_POST, body)

func request_server_scout_purchase(player_id: String, callback: Callable) -> void:
	if auth_access.is_empty() or server_spend_inflight:
		return
	server_spend_inflight = true
	server_spend_callback = callback
	server_spend_request_id = RankedRules.request_id()
	cloud_send("scout_purchase", "%s/rest/v1/rpc/godot_scout_purchase" % SUPABASE_URL, supabase_headers(true), HTTPClient.METHOD_POST, JSON.stringify({"p_request_id": server_spend_request_id, "p_player_id": player_id}))

func request_server_market_fee(kind: String, player_id: String, callback: Callable) -> void:
	if auth_access.is_empty() or server_spend_inflight:
		return
	server_spend_inflight = true
	server_spend_callback = callback
	server_spend_request_id = RankedRules.request_id()
	var rpc := "godot_sign_player" if kind == "sign_player" else "godot_trade_fee"
	cloud_send(kind, "%s/rest/v1/rpc/%s" % [SUPABASE_URL, rpc], supabase_headers(true), HTTPClient.METHOD_POST, JSON.stringify({"p_request_id": server_spend_request_id, "p_player_id": player_id}))

func cloud_send(kind: String, url: String, headers: PackedStringArray, method: int = HTTPClient.METHOD_GET, body: String = "") -> void:
	ensure_cloud()
	# Reopening a screen must not queue identical reads behind a slow request.
	if method == HTTPClient.METHOD_GET:
		if cloud_active.get("url", "") == url and cloud_pending == kind:
			return
		for queued in cloud_queue:
			if queued.get("kind") == kind and queued.get("url") == url:
				return
	if cloud_is_busy() or not cloud_pending.is_empty():
		cloud_queue.append({
			"kind": kind,
			"url": url,
			"headers": headers,
			"method": method,
			"body": body,
		})
		return
	_cloud_fire(kind, url, headers, method, body)

func _cloud_fire(kind: String, url: String, headers: PackedStringArray, method: int, body: String) -> void:
	cloud_active = {"kind": kind, "url": url, "headers": headers, "method": method, "body": body}
	cloud_retry_count = 0
	cloud_failed.clear()
	cloud_started_at_ms = Time.get_ticks_msec()
	cloud_status = "正在連接雲端…"
	cloud_pending = kind
	_cloud_request_active()

func _cloud_request_active() -> void:
	cloud_retry_at_ms = 0
	var err := cloud_http.request(str(cloud_active.url), PackedStringArray(cloud_active.headers), int(cloud_active.method), str(cloud_active.body))
	if err != OK:
		_on_cloud_http(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

func cloud_can_retry(result: int, code: int) -> bool:
	# Settlement is idempotent by (owner_id, match_id), so retrying it is safe
	# even when the response was lost after the server committed the ledger row.
	var safe := int(cloud_active.get("method", -1)) == HTTPClient.METHOD_GET or cloud_pending.begins_with("sync_save_") or cloud_pending in ["push", "push_account", "push_legacy", "ranked_status", "ranked_play", "ranked_join", "ranked_leave", "install_ping", "settle_match", "economy_spend", "scout_purchase", "sign_player", "trade_fee"]
	return safe and cloud_retry_count < CLOUD_MAX_RETRIES and (result != HTTPRequest.RESULT_SUCCESS or code in [408, 429, 500, 502, 503, 504])

func cancel_cloud_requests() -> void:
	cloud_generation += 1
	ranked_loading = false
	if is_instance_valid(cloud_http):
		cloud_http.cancel_request()
		cloud_http.queue_free()
		cloud_http = null
	cloud_pending = ""
	cloud_queue.clear()
	cloud_active.clear()
	cloud_failed.clear()
	cloud_retry_at_ms = 0
	cloud_retry_count = 0
	cloud_status = "已暫停雲端同步，本機存檔保留"
	# A canceled request must not leave a spend callback locked forever (for
	# example after an expired token or a manually canceled network request).
	server_spend_inflight = false
	server_spend_authorized = false
	server_spend_balance.clear()
	server_spend_request_id = ""
	server_spend_callback = Callable()

func retry_cloud_read() -> void:
	if not cloud_pending.is_empty() or cloud_failed.is_empty():
		return
	var failed := cloud_failed.duplicate(true)
	if int(failed.get("method", -1)) != HTTPClient.METHOD_GET:
		return
	if str(failed.kind) in ["pull_slots", "pull", "pull_account"]:
		cloud_pull()
		return
	cloud_send(str(failed.kind), str(failed.url), supabase_headers(true), int(failed.method), str(failed.body))

func cloud_status_panel() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 260
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := wrap_label("正在連接雲端…", 12, TEXT)
	label.name = "Status"
	box.add_child(label)
	var progress := ProgressBar.new()
	progress.name = "Progress"
	progress.custom_minimum_size.y = 10
	progress.add_theme_stylebox_override("background", panel_style(Color("132a3e"), Color("35546b"), 5, 1))
	progress.add_theme_stylebox_override("fill", panel_style(CYAN, CYAN, 5, 0))
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(progress)
	var retry := action_button("重新讀取雲端", CYAN, retry_cloud_read, Vector2(0, 36))
	retry.name = "Retry"
	box.add_child(retry)
	cloud_status_widgets.append(box)
	return box

func tick_cloud_status() -> void:
	var now := Time.get_ticks_msec()
	if cloud_retry_at_ms > 0 and now >= cloud_retry_at_ms and not cloud_pending.is_empty():
		_cloud_request_active()
	for i in range(cloud_status_widgets.size() - 1, -1, -1):
		var box := cloud_status_widgets[i]
		if not is_instance_valid(box) or not box.is_inside_tree():
			cloud_status_widgets.remove_at(i)
			continue
		var waiting := not cloud_pending.is_empty()
		var progress := box.get_node("Progress") as ProgressBar
		progress.visible = waiting
		var total := cloud_http.get_body_size() if waiting and is_instance_valid(cloud_http) else -1
		progress.indeterminate = total <= 0
		if total > 0:
			progress.value = minf(99.0, 100.0 * cloud_http.get_downloaded_bytes() / total)
		var message := cloud_status
		if waiting:
			message = "雲端回應較慢，正在重試 %d/%d" % [cloud_retry_count, CLOUD_MAX_RETRIES] if cloud_retry_count > 0 else "正在讀取／同步雲端"
			message += " · 已等候 %d 秒" % ((now - cloud_started_at_ms) / 1000)
		(box.get_node("Status") as Label).text = message
		box.get_node("Retry").visible = not waiting and int(cloud_failed.get("method", -1)) == HTTPClient.METHOD_GET

func _cloud_flush() -> void:
	if cloud_queue.is_empty():
		return
	if cloud_is_busy() or not cloud_pending.is_empty():
		return
	var next: Dictionary = cloud_queue.pop_front()
	_cloud_fire(
		str(next.get("kind", "")),
		str(next.get("url", "")),
		PackedStringArray(next.get("headers", PackedStringArray())),
		int(next.get("method", HTTPClient.METHOD_GET)),
		str(next.get("body", ""))
	)

func supabase_headers(use_user := false) -> PackedStringArray:
	var token := auth_access if use_user and not auth_access.is_empty() else SUPABASE_ANON
	return PackedStringArray([
		"apikey: %s" % SUPABASE_ANON,
		"Authorization: Bearer %s" % token,
		"Content-Type: application/json",
		"Prefer: return=representation",
	])

func analytics_platform() -> String:
	if OS.has_feature("ios"):
		return "ios"
	if OS.has_feature("android"):
		return "android"
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("desktop"):
		return "desktop"
	return "unknown"

func track_event(event_name: String, properties: Dictionary = {}) -> void:
	# Analytics is opt-in through account login and never blocks gameplay.
	if auth_access.is_empty() or auth_user_id.is_empty() or event_name.is_empty():
		return
	var safe: Dictionary = {}
	for key in properties:
		var k := str(key)
		if k.length() <= 32 and not k.contains("email") and not k.contains("token") and not k.contains("password"):
			safe[k] = properties[key]
	var row := {"owner_id": auth_user_id, "event_name": event_name.left(64), "platform": analytics_platform(), "game_version": APP_VERSION, "properties": safe}
	cloud_send("analytics_" + event_name, "%s/rest/v1/godot_analytics_events" % SUPABASE_URL, supabase_headers(true), HTTPClient.METHOD_POST, JSON.stringify(row))

func _ping_anonymous_install() -> void:
	if analytics_install_pinged:
		return
	var path := "user://tb_analytics_install_id.txt"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			analytics_install_id = file.get_as_text().strip_edges()
	if analytics_install_id.is_empty() or not _looks_like_uuid(analytics_install_id):
		analytics_install_id = RankedRules.request_id()
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(analytics_install_id)
	if analytics_install_id.is_empty():
		return
	analytics_install_pinged = true
	var body := JSON.stringify({
		"p_install_id": analytics_install_id,
		"p_platform": analytics_platform(),
		"p_game_version": APP_VERSION,
	})
	cloud_send("install_ping", "%s/rest/v1/rpc/godot_install_ping" % SUPABASE_URL, supabase_headers(), HTTPClient.METHOD_POST, body)

func _looks_like_uuid(value: String) -> bool:
	return value.length() == 36 and value.count("-") == 4

func start_auth_listener() -> void:
	# Browsers cannot host a TCP callback server. Do not resize or treat them as native windows.
	if OS.has_feature("web"):
		return
	if auth_server != null and auth_server.is_listening():
		auth_redirect = "http://127.0.0.1:%d/callback" % auth_listen_port
		return
	auth_server = TCPServer.new()
	for port in [8765, 8766, 8767, 8770]:
		if auth_server.listen(port, "127.0.0.1") == OK:
			auth_listen_port = port
			auth_redirect = "http://127.0.0.1:%d/callback" % port
			return
	auth_server = null
	flash_notice("本機登入回呼埠被占用，請先關掉舊的遊戲視窗")

func poll_auth_server() -> void:
	if auth_server == null or not auth_server.is_listening():
		return
	if not auth_server.is_connection_available():
		return
	var peer := auth_server.take_connection()
	if peer == null:
		return
	var raw := ""
	for _i in 12:
		peer.poll()
		if peer.get_available_bytes() > 0:
			raw += peer.get_utf8_string(peer.get_available_bytes())
			if raw.contains("\r\n\r\n") or raw.contains("\n\n"):
				break
		OS.delay_msec(8)
	var first := raw.get_slice("\n", 0).strip_edges()
	var path := first.get_slice(" ", 1) if first.begins_with("GET ") else first
	var query := path.get_slice("?", 1) if path.contains("?") else ""
	if path.contains("/callback") and not query.contains("code=") and not query.contains("access_token="):
		var html := "<html><body style='background:#07111c;color:#f6f8fb;font-family:sans-serif;padding:40px'><h2>正在回到台籃模擬器</h2><script>location.replace('/token?'+location.hash.substring(1)+'&'+location.search.substring(1));</script></body></html>"
		_auth_http_ok(peer, html)
	elif query.contains("code=") or query.contains("access_token="):
		var token := _query_value(query, "access_token")
		var code := _query_value(query, "code")
		var error := _query_value(query, "error_description")
		if error.is_empty():
			error = _query_value(query, "error")
		var ok_html := "<html><body style='background:#07111c;color:#55d6a0;font-family:sans-serif;padding:40px'><h2>登入成功，請回遊戲視窗。</h2></body></html>"
		if not error.is_empty():
			ok_html = "<html><body style='background:#07111c;color:#ed5b62;font-family:sans-serif;padding:40px'><h2>登入失敗</h2><p>%s</p></body></html>" % error.xml_escape()
		_auth_http_ok(peer, ok_html)
		if not token.is_empty():
			apply_access_token(token)
		elif not code.is_empty():
			exchange_auth_code(code)
		elif not error.is_empty():
			flash_notice("登入失敗：%s" % error.uri_decode())
	else:
		peer.put_data("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n".to_utf8_buffer())
	peer.disconnect_from_host()

func _auth_http_ok(peer: StreamPeerTCP, html: String) -> void:
	var body := html.to_utf8_buffer()
	peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\nContent-Length: %d\r\n\r\n" % body.size()).to_utf8_buffer())
	peer.put_data(body)

func _query_value(query: String, key: String) -> String:
	for part in query.split("&"):
		if part.begins_with(key + "="):
			return part.substr(key.length() + 1).uri_decode()
	return ""

func pkce_verifier() -> String:
	return Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(32)).replace("+", "-").replace("/", "_").replace("=", "")

func pkce_challenge(verifier: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(verifier.to_utf8_buffer())
	return Marshalls.raw_to_base64(ctx.finish()).replace("+", "-").replace("/", "_").replace("=", "")

func start_oauth(provider: String) -> void:
	if OS.has_feature("web"):
		if provider != "google":
			flash_notice("網頁版目前提供 Google 或信箱驗證碼登入。")
			return
		web_auth_consumed = false
		# Always return to the standalone game page.  Using top.location matters
		# when the game is opened inside play.html's iframe; otherwise OAuth can
		# finish in the iframe and appear to send the player back to the homepage.
		var web_redirect := "https://eve1995927-svg.github.io/basketballtw/game/index.html"
		var url := "%s/auth/v1/authorize?provider=google&redirect_to=%s&response_type=token" % [SUPABASE_URL, web_redirect.uri_encode()]
		flash_notice("正在開啟 Google 登入…")
		JavaScriptBridge.eval("(window.top || window).location.href=" + JSON.stringify(url))
		return
	start_auth_listener()
	if auth_server == null:
		return
	oauth_code_verifier = pkce_verifier()
	var challenge := pkce_challenge(oauth_code_verifier)
	var url := "%s/auth/v1/authorize?provider=%s&redirect_to=%s&code_challenge=%s&code_challenge_method=S256" % [
		SUPABASE_URL,
		provider,
		auth_redirect.uri_encode(),
		challenge.uri_encode(),
	]
	flash_notice("瀏覽器會打開，登入後回到遊戲。")
	OS.shell_open(url)

func poll_web_auth_callback() -> void:
	if not OS.has_feature("web") or web_auth_consumed:
		return
	var fragment := str(JavaScriptBridge.eval("window.location.hash.substring(1)"))
	if fragment.is_empty() or not fragment.contains("access_token="):
		return
	web_auth_consumed = true
	var token := _query_value(fragment, "access_token")
	var refresh := _query_value(fragment, "refresh_token")
	if token.is_empty():
		web_auth_consumed = false
		return
	auth_refresh = refresh
	JavaScriptBridge.eval("window.history.replaceState({}, document.title, window.location.pathname + window.location.search)")
	apply_access_token(token)

func exchange_auth_code(code: String) -> void:
	var body := JSON.stringify({
		"auth_code": code,
		"code_verifier": oauth_code_verifier,
	})
	cloud_send("verify", "%s/auth/v1/token?grant_type=pkce" % SUPABASE_URL, supabase_headers(), HTTPClient.METHOD_POST, body)

func send_gmail_otp() -> void:
	if not login_email.contains("@") or not login_email.contains("."):
		flash_notice("請先填電子信箱；離線遊玩不需填寫。")
		return
	if Time.get_ticks_msec() < otp_retry_at_ms:
		flash_notice("請勿重複寄送，%d 秒後可再試；也可以先離線遊玩。" % maxi(1, int(ceil(float(otp_retry_at_ms - Time.get_ticks_msec()) / 1000.0))))
		return
	otp_retry_at_ms = Time.get_ticks_msec() + 60000
	var body := JSON.stringify({"email": login_email, "create_user": true})
	cloud_send("otp", "%s/auth/v1/otp" % SUPABASE_URL, supabase_headers(), HTTPClient.METHOD_POST, body)
	flash_notice("正在寄送驗證碼…")

func verify_gmail_otp() -> void:
	if login_email.is_empty() or login_otp.length() < 6 or login_otp.length() > 10 or not login_otp.is_valid_int():
		flash_notice("請填信箱與信件中的完整驗證碼（6～10 位數字）")
		return
	var body := JSON.stringify({"email": login_email, "token": login_otp, "type": "email"})
	cloud_send("verify", "%s/auth/v1/verify" % SUPABASE_URL, supabase_headers(), HTTPClient.METHOD_POST, body)

func apply_access_token(token: String) -> void:
	cancel_cloud_requests()
	cloud_restore_incomplete = true
	auth_access = token
	cloud_send("user", "%s/auth/v1/user" % SUPABASE_URL, supabase_headers(true), HTTPClient.METHOD_GET)

func refresh_auth_session() -> void:
	cloud_restore_incomplete = true
	if auth_refresh.is_empty():
		pending_enter_after_auth = false
		show_login()
		return
	cloud_send("refresh", "%s/auth/v1/token?grant_type=refresh_token" % SUPABASE_URL, supabase_headers(), HTTPClient.METHOD_POST, JSON.stringify({"refresh_token": auth_refresh}))

func logout_account() -> void:
	cancel_cloud_requests()
	release_gate_pending = false
	release_gate_checked = false
	release_gate_blocked = false
	sync_owner = ""
	sync_state.clear()
	sync_seen.clear()
	sync_error = false
	sync_read_complete = false
	cloud_refresh_attempted = false
	ranked_state.clear()
	ranked_message = ""
	ranked_owner = ""
	ranked_request_owner = ""
	activity_cloud_schedule.clear()
	activity_cloud_leaderboard.clear()
	cloud_local_baseline.clear()
	cloud_restore_incomplete = false
	var remembered := login_email if not login_email.is_empty() else auth_email
	auth_access = ""
	auth_refresh = ""
	auth_user_id = ""
	auth_email = ""
	analytics_session_sent = false
	login_email = remembered
	oauth_code_verifier = ""
	pending_enter_after_auth = false
	cloud_fail_notice_shown = false
	var file := FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"email": remembered}))
	flash_notice("已登出")
	show_login()

func persist_auth() -> void:
	if not auth_email.is_empty():
		login_email = auth_email
	var file := FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"access": auth_access,
			"refresh": auth_refresh,
			"user_id": auth_user_id,
			"email": auth_email if not auth_email.is_empty() else login_email,
		}))

func restore_auth_session() -> void:
	if not FileAccess.file_exists(AUTH_PATH):
		return
	var file := FileAccess.open(AUTH_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	auth_access = str(data.get("access", ""))
	auth_refresh = str(data.get("refresh", ""))
	auth_user_id = str(data.get("user_id", ""))
	auth_email = str(data.get("email", ""))
	if login_email.is_empty():
		login_email = auth_email
	apply_designer_unlocks()

func cloud_push(data: Dictionary) -> bool:
	return CloudSync.enqueue(self,active_save_slot,data)

func cloud_push_account() -> void:
	if auth_access.is_empty() or auth_user_id.is_empty():
		return
	var blob := {
		"extra_save_unlocked": extra_save_unlocked,
		"iap_receipts": iap_receipts,
		"last_slot": active_save_slot,
	}
	var headers := supabase_headers(true)
	headers.append("Prefer: resolution=merge-duplicates,return=minimal")
	var row := {"owner_id": auth_user_id, "account_json": blob, "updated_at": Time.get_datetime_string_from_system(true)}
	cloud_send("push_account", "%s/rest/v1/godot_account_blob?on_conflict=owner_id" % SUPABASE_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(row))

func cloud_pull() -> void:
	if auth_access.is_empty():
		return
	if cloud_pending in ["pull_slots", "pull", "pull_account"]:
		return
	cloud_restore_incomplete = true
	cloud_restore_conflict = false
	CloudSync.begin_pull(self)
	cloud_local_baseline.clear()
	for slot in 10:
		cloud_local_baseline[slot] = SaveStore.read_save(slot_save_path(slot))
	cloud_send("pull_slots", "%s/rest/v1/godot_club_slots?select=slot,save_json,revision" % SUPABASE_URL, supabase_headers(true))

func import_cloud_slot(slot: int, data: Dictionary, revision := 1) -> Error:
	return CloudSync.ingest(self,slot,data,revision)

func request_release_gate() -> void:
	if release_gate_pending or release_gate_checked:
		return
	release_gate_pending = true
	cloud_send("release_config", "%s/rest/v1/godot_release_config?select=platform,minimum_version,maintenance,message" % SUPABASE_URL, supabase_headers())

func version_at_least(current: String, minimum: String) -> bool:
	var current_parts := current.split(".")
	var minimum_parts := minimum.split(".")
	for i in 3:
		var cv := 0
		var mv := 0
		if i < current_parts.size() and str(current_parts[i]).is_valid_int():
			cv = int(current_parts[i])
		if i < minimum_parts.size() and str(minimum_parts[i]).is_valid_int():
			mv = int(minimum_parts[i])
		if cv != mv:
			return cv > mv
	return true

func show_release_block(title_text: String, message: String) -> void:
	pending_enter_after_auth = false
	release_gate_blocked = true
	var content := begin_screen(title_text, "請更新後再進入球場", 0, false)
	content.add_child(callout("版本狀態", message, ORANGE))
	content.add_child(action_button("回到登入畫面", Color("254e6b"), func():
		release_gate_checked = false
		release_gate_blocked = false
		show_login()
	, Vector2(0, 48)))

func _on_cloud_http(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if cloud_pending.is_empty():
		return # A canceled account must never receive a late response.
	if result == HTTPRequest.RESULT_SUCCESS and code == 401 and cloud_pending not in ["refresh","user","verify","otp"]:
		cancel_cloud_requests()
		cloud_restore_incomplete = true
		if not cloud_refresh_attempted and not auth_refresh.is_empty():
			cloud_refresh_attempted = true
			refresh_auth_session()
			cloud_status = "正在更新登入狀態，本機進度與待確認請求保留。"
		else:
			cloud_status = "登入已過期，本機進度保留；請到設定重新登入。"
			flash_notice(cloud_status)
		return
	if cloud_can_retry(result, code):
		cloud_retry_count += 1
		var delay_ms := 1000 * cloud_retry_count
		for header in headers:
			if header.to_lower().begins_with("retry-after:"):
				delay_ms = maxi(delay_ms, clampi(int(header.get_slice(":", 1).strip_edges()) * 1000, 0, 10000))
		cloud_retry_at_ms = Time.get_ticks_msec() + delay_ms
		return
	var payload := body.get_string_from_utf8()
	var kind := cloud_pending
	var invalid_read := false
	if kind.begins_with("pull") and result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		var parser := JSON.new()
		invalid_read = parser.parse(payload) != OK or not (parser.data is Array)
	var failed := invalid_read or result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300
	if failed:
		cloud_failed = cloud_active.duplicate(true)
		cloud_status = "雲端尚未連上，本機存檔保留；可重試或先離線遊玩。" if code == 0 or code >= 500 or code in [408, 429] else "雲端請求未完成（%d），本機存檔保留。" % code
		if invalid_read:
			cloud_status = "雲端回應不完整，本機資料保留；請重新讀取。"
	else:
		cloud_failed.clear()
		cloud_status = "雲端資料已接收"
	cloud_pending = ""
	cloud_active.clear()
	cloud_retry_at_ms = 0
	if failed and kind in ["pull", "pull_slots", "pull_account"] and code != 404:
		# Do not fall back to an old save on a network error, or upload local defaults.
		cloud_queue.clear()
		return
	if invalid_read:
		call_deferred("_cloud_flush")
		return
	_dispatch_cloud_http(kind, code if result == HTTPRequest.RESULT_SUCCESS else 0, payload)
	call_deferred("_cloud_flush")

func auth_error_message(code: int, payload: String, sending := false) -> String:
	var parser := JSON.new()
	var parsed: Variant = parser.data if parser.parse(payload) == OK else {}
	var error_code := str(parsed.get("error_code", parsed.get("code", ""))) if parsed is Dictionary else ""
	if code == 0:
		return "連線失敗，請確認網路；也可以先離線遊玩。"
	if code == 429 or error_code.begins_with("over_"):
		return "驗證信寄送已達上限，請稍後再試或先離線遊玩。" if sending else "登入嘗試太頻繁，請稍後再試。"
	if error_code == "email_address_not_authorized":
		return "驗證信服務暫不支援此信箱，請先離線遊玩並通知管理員。"
	if error_code in ["email_provider_disabled", "signup_disabled"]:
		return "此登入方式暫未開放，請先離線遊玩。"
	if code >= 500:
		return "登入服務暫時無法使用，請稍後再試；本機存檔不受影響。"
	return "驗證信未寄出，請確認信箱或稍後再試。" if sending else "驗證碼無效或已過期，請確認信件中的完整驗證碼。"

func _dispatch_cloud_http(kind: String, code: int, payload: String) -> void:
	if kind == "install_ping":
		# Anonymous telemetry is best effort and must never interrupt play.
		return
	if kind.begins_with("sync_save_"):
		CloudSync.complete(self,kind,code,payload)
		return
	if kind == "settle_match":
		server_settlement_inflight = false
		if code < 200 or code >= 300:
			server_settlement_balance.clear()
			show_settlement_retry_notice("伺服器尚未確認比賽結果，請保持網路後重試。")
			return
		var settled: Variant = JSON.parse_string(payload)
		if settled is Array and not settled.is_empty():
			settled = settled[0]
		if not (settled is Dictionary) or not (settled.get("balance", {}) is Dictionary):
			show_settlement_retry_notice("結算回應格式錯誤，請稍後重試。")
			return
		server_settlement_balance = settled.get("balance", {}).duplicate(true)
		server_settlement_ready = true
		call_deferred("show_post_match")
		return
	if kind == "release_config":
		release_gate_pending = false
		release_gate_checked = true
		if code < 200 or code >= 300:
			cloud_status = "版本服務暫時無法讀取，先保留目前版本；離線遊玩不受影響。"
			finish_auth_enter()
			return
		var config_rows: Variant = JSON.parse_string(payload)
		if config_rows is Dictionary:
			config_rows = [config_rows]
		if not (config_rows is Array):
			cloud_status = "版本資訊格式不完整，先保留目前版本。"
			finish_auth_enter()
			return
		var selected_config: Dictionary = {}
		var fallback_config: Dictionary = {}
		var platform := analytics_platform()
		for item in config_rows:
			if not (item is Dictionary):
				continue
			var row: Dictionary = item
			if str(row.get("platform", "")) == "all":
				fallback_config = row
			elif str(row.get("platform", "")) == platform:
				selected_config = row
		if selected_config.is_empty():
			selected_config = fallback_config
		if not selected_config.is_empty():
			var minimum := str(selected_config.get("minimum_version", "0.0.0"))
			var maintenance := bool(selected_config.get("maintenance", false))
			var message := str(selected_config.get("message", ""))
			if maintenance:
				show_release_block("服務維護中", message if not message.is_empty() else "伺服器正在維護，請稍後再試。")
				return
			if not version_at_least(APP_VERSION, minimum):
				show_release_block("需要更新", message if not message.is_empty() else "目前版本已過期，請從官方下載最新版本。")
				return
		finish_auth_enter()
		return
	if kind == "economy_bootstrap":
		if code < 200 or code >= 300:
			cloud_status = "雲端資源尚未同步，本機資料保留；請稍後重試。"
			finish_auth_enter()
			return
		var account_balance: Variant = JSON.parse_string(payload)
		if account_balance is Array and not account_balance.is_empty():
			account_balance = account_balance[0]
		if not (account_balance is Dictionary):
			cloud_status = "雲端資源回應格式錯誤，本機資料保留。"
			finish_auth_enter()
			return
		budget_million = maxi(0, int(account_balance.get("budget_million", budget_million)))
		gold = maxi(0, int(account_balance.get("gold", gold)))
		scout_points = maxi(0, int(account_balance.get("scout_points", scout_points)))
		training_points = maxi(0, int(account_balance.get("training_points", training_points)))
		save_game()
		flash_notice("已同步雲端資源")
		finish_auth_enter()
		return
	if kind in ["economy_spend", "scout_purchase", "sign_player", "trade_fee"]:
		server_spend_inflight = false
		var ok := code >= 200 and code < 300
		var spent: Variant = JSON.parse_string(payload) if ok else {}
		if spent is Array and not spent.is_empty():
			spent = spent[0]
		if ok and spent is Dictionary and spent.get("balance", {}) is Dictionary:
			server_spend_balance = spent.get("balance", {}).duplicate(true)
			budget_million = int(server_spend_balance.get("budget_million", budget_million))
			gold = int(server_spend_balance.get("gold", gold))
			scout_points = int(server_spend_balance.get("scout_points", scout_points))
			training_points = int(server_spend_balance.get("training_points", training_points))
			server_spend_authorized = true
		else:
			server_spend_balance.clear()
			server_spend_authorized = false
			flash_notice("雲端扣款未確認，資源未變更；請保持網路後重試。")
		if server_spend_callback.is_valid():
			var cb := server_spend_callback
			server_spend_callback = Callable()
			cb.call(ok and server_spend_authorized)
		return
	if kind.begins_with("ranked_"):
		RankedFlow.complete(self,kind,code,payload)
		return
	if kind == "otp":
		if code >= 200 and code < 300:
			flash_notice("驗證碼已寄出")
		else:
			flash_notice(auth_error_message(code, payload, true))
		return
	if kind == "refresh":
		if code < 200 or code >= 300:
			if code in [400, 401, 403]:
				auth_access = ""
				auth_refresh = ""
				persist_auth()
			pending_enter_after_auth = false
			show_login()
			flash_notice(auth_error_message(code, payload))
			return
		var refreshed = JSON.parse_string(payload)
		if typeof(refreshed) != TYPE_DICTIONARY or str(refreshed.get("access_token", "")).is_empty():
			pending_enter_after_auth = false
			show_login()
			return
		auth_access = str(refreshed.get("access_token", ""))
		if refreshed.has("refresh_token"):
			auth_refresh = str(refreshed.get("refresh_token", auth_refresh))
		persist_auth()
		apply_access_token(auth_access)
		return
	if kind == "verify" or kind == "user":
		if kind == "user" and (code == 401 or code == 403):
			refresh_auth_session()
			return
		if code < 200 or code >= 300:
			pending_enter_after_auth = false
			show_login()
			flash_notice(auth_error_message(code, payload))
			return
		var parsed = JSON.parse_string(payload)
		if typeof(parsed) != TYPE_DICTIONARY:
			pending_enter_after_auth = false
			flash_notice("登入沒成功，請再試一次")
			show_login()
			return
		if parsed.has("access_token"):
			auth_access = str(parsed.get("access_token", auth_access))
			if parsed.has("refresh_token"):
				auth_refresh = str(parsed.get("refresh_token", auth_refresh))
			var user = parsed.get("user", {})
			if user is Dictionary:
				auth_user_id = str(user.get("id", ""))
				auth_email = str(user.get("email", login_email))
		if parsed.has("id") and str(parsed.get("id", "")).length() > 8:
			auth_user_id = str(parsed.get("id", ""))
			auth_email = str(parsed.get("email", auth_email))
		if auth_user_id.is_empty():
			flash_notice("還沒拿到帳號，請再試一次")
			show_login()
			return
		if not auth_email.is_empty():
			login_email = auth_email
		track_event("login_success", {"method": "oauth" if kind == "user" else "email_otp"})
		var changed_profile := local_profile_id != auth_user_id
		if changed_profile:
			cancel_cloud_requests()
		if LocalProfiles.activate(self,auth_user_id) != OK:
			cloud_restore_incomplete = true
			pending_enter_after_auth = false
			show_login()
			flash_notice("帳號存檔隔離準備失敗，原檔保留。請確認裝置空間後重試。")
			return
		persist_auth()
		if changed_profile:
			current_stage = 0
		if current_stage != 0:
			cloud_pull()
			return
		pending_enter_after_auth = true
		if kind == "verify":
			flash_notice("登入成功，存檔會同步雲端")
		show_entering("正在同步存檔…")
		cloud_pull()
		return
	if kind == "pull" or kind == "pull_slots":
		var slot_parser := JSON.new()
		var rows: Variant = slot_parser.data if slot_parser.parse(payload) == OK else null
		if kind == "pull_slots" and code == 404:
			cloud_status = "新版存檔服務暫不可用，本機進度保留；請稍後重新同步。"
			return
		if kind == "pull_slots" and code >= 200 and code < 300 and rows is Array and rows.is_empty():
			# Only consult legacy data after confirming the current slot table is
			# empty, never when the authoritative service is unavailable.
			cloud_send("pull", "%s/rest/v1/godot_club_saves?select=save_json&limit=1" % SUPABASE_URL, supabase_headers(true))
			return
		if kind == "pull" and code == 404:
			rows = []
			code = 200
		if code < 200 or code >= 300 or not (rows is Array):
			cloud_status = "存檔回應不完整，已保留本機資料。請重新登入後再同步。"
			return
		if rows is Array:
			for item in rows:
				if not (item is Dictionary):
					sync_error = true
					cloud_restore_conflict = true
					continue
				if item.has("slot"):
					var slot := int(item.get("slot", 0))
					var blob = item.get("save_json", {})
					if not blob is Dictionary:
						sync_error = true
					if not (blob is Dictionary) or import_cloud_slot(slot, blob, int(item.get("revision",-1))) != OK:
						cloud_restore_conflict = true
						flash_notice("本機與雲端已保留；可到設定確認存檔。")
				elif item.has("save_json"):
					var blob2 = item.get("save_json", {})
					if not blob2 is Dictionary:
						sync_error = true
					if not (blob2 is Dictionary) or import_cloud_slot(int(blob2.get("save_slot", 0)), blob2, 0) != OK:
						cloud_restore_conflict = true
						flash_notice("舊版雲端存檔無法套用，保留原本本機存檔")
				else:
					sync_error = true
					cloud_restore_conflict = true
			CloudSync.finish_slots(self)
			if not rows.is_empty():
				if not cloud_restore_conflict:
					flash_notice("已從雲端取回存檔")
		cloud_send("pull_account", "%s/rest/v1/godot_account_blob?select=account_json" % SUPABASE_URL, supabase_headers(true))
		return
	if kind == "pull_account":
		var account_parser := JSON.new()
		var acc: Variant = account_parser.data if account_parser.parse(payload) == OK else null
		if (code < 200 or code >= 300 or not (acc is Array)) and code != 404:
			cloud_status = "帳戶回應不完整，本機資料保留。請重新登入後再同步。"
			return
		if acc is Array and not acc.is_empty() and (not acc[0] is Dictionary or not acc[0].get("account_json") is Dictionary):
			sync_error = true
			cloud_restore_incomplete = true
			cloud_status = "帳戶資料格式不完整，已暫停上傳並保留本機設定。"
			return
		if acc is Array and not acc.is_empty() and acc[0] is Dictionary:
			var blob = acc[0].get("account_json", {})
			if blob is Dictionary:
				if blob.has("iap_receipts") and blob.iap_receipts is Dictionary:
					iap_receipts = blob.iap_receipts.duplicate(true)
				extra_save_unlocked = bool(blob.get("extra_save_unlocked", extra_save_unlocked)) or bool(iap_receipts.get("extra_save", false))
				if blob.has("last_slot"):
					active_save_slot = int(blob.get("last_slot", active_save_slot))
				save_account()
		cloud_send("economy_bootstrap", "%s/rest/v1/rpc/godot_economy_bootstrap" % SUPABASE_URL, supabase_headers(true), HTTPClient.METHOD_POST, "{}")
		return
	if kind == "pull_activity_schedule" or kind == "pull_activity_leaderboard":
		if code >= 200 and code < 300:
			var activity_rows = JSON.parse_string(payload)
			if activity_rows is Array:
				if kind == "pull_activity_schedule":
					activity_cloud_schedule.clear()
					for item in activity_rows:
						if item is Dictionary:
							activity_cloud_schedule.append(item)
				else:
					activity_cloud_leaderboard.clear()
					for item in activity_rows:
						if item is Dictionary:
							activity_cloud_leaderboard.append(item)
				call_deferred("refresh_activity_cloud_panel", kind)
			else:
				flash_notice("活動資料格式不正確，已保留本地內容")
		elif code != 404:
			flash_notice("活動雲端資料暫時無法讀取，仍可離線遊玩")
		return
	if kind == "push" or kind == "push_account" or kind == "push_legacy" or kind == "push_prediction" or kind == "push_prediction_result" or kind == "push_activity_leaderboard":
		if code >= 200 and code < 300:
			cloud_fail_notice_shown = false
		else:
			notify_cloud_save_offline()
		return

func notify_cloud_save_offline() -> void:
	if cloud_fail_notice_shown or current_stage == 6:
		return
	cloud_fail_notice_shown = true
	flash_notice("本機已存檔。雲端暫時連不上，離線也能玩。")

func finish_auth_enter() -> void:
	# Check the public release switch before entering the lobby. A failed or
	# malformed config is fail-open so players can still play offline; only an
	# explicit maintenance flag or minimum-version rule blocks online entry.
	if not release_gate_checked:
		request_release_gate()
		return
	if release_gate_blocked:
		return
	if not analytics_session_sent and not auth_user_id.is_empty():
		analytics_session_sent = true
		track_event("session_start", {"league": current_league})
	sync_read_complete = not sync_error
	if sync_read_complete:
		cloud_refresh_attempted = false
	cloud_restore_conflict = cloud_restore_conflict or sync_error or not CloudSync.conflicts(self).is_empty()
	cloud_restore_incomplete = cloud_restore_conflict
	if cloud_restore_conflict:
		cloud_status = "部分存檔無法套用或已有本機新進度，暫停上傳以保護資料。"
	cloud_local_baseline.clear()
	if not cloud_restore_incomplete:
		for slot in 10:
			var local := SaveStore.read_save(slot_save_path(slot))
			if not local.is_empty():
				CloudSync.enqueue(self,slot,local)
	if not pending_enter_after_auth:
		return
	pending_enter_after_auth = false
	if current_stage != 0:
		return
	continue_after_login()

func load_game(then_show := true) -> void:
	var path := slot_save_path(active_save_slot)
	# Only slot zero may migrate the legacy file. Never clone a different club.
	if active_save_slot == 0 and not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		path = legacy_save_path()
	var data := SaveStore.read_save(path)
	if data.is_empty():
		if then_show:
			show_team_build()
		return
	var migrate_economy := int(data.get("economy_version", 0)) < ECONOMY_VERSION
	if migrate_economy:
		var backup_path := path + ".before_economy_v1"
		if not FileAccess.file_exists(backup_path):
			if SaveStore.write_save(backup_path, data) != OK:
				flash_notice("更新前備份失敗，未更動存檔。請確認裝置空間後重試。")
				return
	# Missing fields in legacy saves must use fresh-club defaults, never another slot.
	reset_club_state()
	club_name = str(data.get("club_name", club_name))
	if data.get("draft_state") is Dictionary:
		draft_state = data.draft_state.duplicate(true)
	if data.get("drafted_prospect_ids") is Array:
		drafted_prospect_ids = data.drafted_prospect_ids.duplicate()
	club_logo_id = str(data.get("club_logo_id", club_logo_id))
	ensure_club_logo_id()
	selected_foundation = int(data.get("selected_foundation", 0))
	selected_tactic = str(data.get("selected_tactic", selected_tactic))
	selected_defense = str(data.get("selected_defense", selected_defense))
	is_home_game = bool(data.get("is_home_game", true))
	season_wins = int(data.get("season_wins", 0))
	season_losses = int(data.get("season_losses", 0))
	season_games = int(data.get("season_games", 0))
	chemistry = int(data.get("chemistry", 48))
	budget_million = int(data.get("budget_million", career_rules.get("starter_budget_million", STARTING_BUDGET_MILLION)))
	if migrate_economy:
		budget_million += ECONOMY_COMPENSATION
	economy_version = ECONOMY_VERSION
	scout_points = int(data.get("scout_points", STARTING_SCOUT_POINTS))
	scout_floor_game = int(data.get("scout_floor_game", -1))
	training_points = int(data.get("training_points", STARTING_TRAINING_POINTS))
	opponent_index = int(data.get("opponent_index", 0))
	last_mvp = str(data.get("last_mvp", last_mvp))
	last_match_played = bool(data.get("last_match_played", season_games > 0))
	if data.has("last_score") and data.last_score is Array and data.last_score.size() >= 2:
		last_score = [int(data.last_score[0]), int(data.last_score[1])]
	if data.has("last_box") and data.last_box is Dictionary:
		last_box = data.last_box.duplicate(true)
	if data.has("quarter_scores") and data.quarter_scores is Array:
		quarter_scores = data.quarter_scores.duplicate(true)
	if quarter_scores.size() < 2 or not (quarter_scores[0] is Array) or not (quarter_scores[1] is Array):
		quarter_scores = [[], []]
	last_event = str(data.get("last_event", last_event))
	last_skill_event = str(data.get("last_skill_event", last_skill_event))
	last_news = str(data.get("last_news", last_news))
	trade_notice_pending = bool(data.get("trade_notice_pending", false))
	gacha_opened = int(data.get("gacha_opened", 0))
	scout_pity_progress = int(data.get("scout_pity_progress", 0))
	scout_board_serial = int(data.get("scout_board_serial", 0))
	supporter_theme = str(data.get("supporter_theme", "標準球館"))
	locker_room_theme = str(data.get("locker_room_theme", "標準更衣室"))
	vault_capacity_bonus = maxi(0, int(data.get("vault_capacity_bonus", 0)))
	second_team_unlocked = bool(data.get("second_team_unlocked", false))
	store_cosmetics_owned.assign(["standard"])
	if data.get("store_cosmetics_owned") is Array:
		for cosmetic in data.store_cosmetics_owned:
			var cosmetic_id := str(cosmetic)
			if not cosmetic_id.is_empty() and not store_cosmetics_owned.has(cosmetic_id):
				store_cosmetics_owned.append(cosmetic_id)
	# Older saves already using a theme keep it unlocked after this store update.
	var legacy_theme_id: String = str({"夜場靛藍":"arena_night", "冠軍金色主場":"arena_champion", "賽博龐克主場":"arena_neon"}.get(supporter_theme, ""))
	if not legacy_theme_id.is_empty() and not store_cosmetics_owned.has(legacy_theme_id):
		store_cosmetics_owned.append(legacy_theme_id)
	active_challenge = str(data.get("active_challenge", ""))
	last_progress_event = str(data.get("last_progress_event", last_progress_event))
	if data.has("challenge_progress") and data.challenge_progress is Dictionary:
		challenge_progress = data.challenge_progress.duplicate(true)
	if data.has("challenge_completed") and data.challenge_completed is Dictionary:
		challenge_completed = data.challenge_completed.duplicate(true)
	mission_alert = bool(data.get("mission_alert", false))
	daily_checkin_date = str(data.get("daily_checkin_date", ""))
	daily_checkin_streak = int(data.get("daily_checkin_streak", 0))
	daily_checkin_days = int(data.get("daily_checkin_days", 0))
	monthly_pass_active = bool(data.get("monthly_pass_active", false)) or bool(iap_receipts.get("monthly_pass", false))
	if monthly_pass_active and not store_cosmetics_owned.has("arena_monthly"):
		store_cosmetics_owned.append("arena_monthly")
	monthly_pass_claimed_date = str(data.get("monthly_pass_claimed_date", ""))
	monthly_pass_claimed_days = clampi(int(data.get("monthly_pass_claimed_days", 0)), 0, 30)
	scout_free_refresh_date = str(data.get("scout_free_refresh_date", ""))
	prediction_match_key = str(data.get("prediction_match_key", ""))
	prediction_pick = str(data.get("prediction_pick", ""))
	prediction_margin = str(data.get("prediction_margin", ""))
	prediction_stake = int(data.get("prediction_stake", 0))
	prediction_points = int(data.get("prediction_points", 0))
	prediction_correct = int(data.get("prediction_correct", 0))
	prediction_badges.clear()
	if data.get("prediction_badges") is Array:
		for badge in data.prediction_badges:
			prediction_badges.append(str(badge))
	equipped_badges.clear()
	if data.get("equipped_badges") is Array:
		for badge in data.equipped_badges:
			if equipped_badges.size() >= 2:
				break
			var badge_id := str(badge)
			if not equipped_badges.has(badge_id):
				equipped_badges.append(badge_id)
	async_season_active = bool(data.get("async_season_active", false))
	async_season_game = int(data.get("async_season_game", 0))
	async_season_wins = int(data.get("async_season_wins", 0))
	async_season_losses = int(data.get("async_season_losses", 0))
	async_season_points = int(data.get("async_season_points", 0))
	async_season_roster_snapshot.clear()
	if data.get("async_season_roster_snapshot") is Array:
		for item in data.async_season_roster_snapshot:
			if item is Dictionary:
				async_season_roster_snapshot.append(item.duplicate(true))
	async_season_settled_key = str(data.get("async_season_settled_key", ""))
	national_tournament = str(data.get("national_tournament", national_tournament))
	national_registered = bool(data.get("national_registered", false))
	national_games = int(data.get("national_games", 0))
	national_wins = int(data.get("national_wins", 0))
	national_last_result = str(data.get("national_last_result", national_last_result))
	if data.has("national_roster") and data.national_roster is Array:
		national_roster.clear()
		for item in data.national_roster:
			if item is Dictionary:
				national_roster.append(refresh_stored_player(item.duplicate(true)))
	if data.has("team_players") and data.team_players is Array:
		team_players.clear()
		for item in data.team_players:
			if item is Dictionary:
				team_players.append(refresh_stored_player(item.duplicate(true)))
	active_team_index = clampi(int(data.get("active_team_index", 0)), 0, MAX_TEAM_PROFILES - 1)
	team_profiles.clear()
	if data.get("team_profiles") is Array:
		for profile in data.team_profiles:
			if profile is Dictionary:
				team_profiles.append(profile.duplicate(true))
	if team_profiles.is_empty():
		team_profiles.append({"name": club_name, "logo_id": club_logo_id, "players": team_players.duplicate(true)})
	while team_profiles.size() < MAX_TEAM_PROFILES:
		team_profiles.append({})
	# Existing saves that already used team two keep access after the store change.
	if team_profiles.size() > 1 and not team_profiles[1].is_empty():
		second_team_unlocked = true
	gold = int(data.get("gold", STARTING_GOLD))
	salary_cap_bonus = int(data.get("salary_cap_bonus", 0))
	win_streak = int(data.get("win_streak", 0))
	gacha_candidates.clear()
	if data.has("gacha_candidates") and data.gacha_candidates is Array:
		for item in data.gacha_candidates:
			if item is Dictionary:
				gacha_candidates.append(refresh_stored_player(item.duplicate(true)))
	current_league = str(data.get("current_league", "SBL"))
	season_phase = str(data.get("season_phase", "regular"))
	if data.get("playoff_state") is Dictionary:
		playoff_state = data.playoff_state.duplicate(true)
	national_unlocked = bool(data.get("national_unlocked", false))
	coach_id = str(data.get("coach_id", coach_id))
	combo_label = str(data.get("combo_label", ""))
	tutorial_seen = bool(data.get("tutorial_seen", false))
	if data.has("unlocked_leagues") and data.unlocked_leagues is Array:
		unlocked_leagues = data.unlocked_leagues.duplicate()
	if data.has("championships") and data.championships is Dictionary:
		championships = data.championships.duplicate(true)
	if data.has("unlocked_offense") and data.unlocked_offense is Array:
		unlocked_offense = data.unlocked_offense.duplicate()
	if data.has("unlocked_defense") and data.unlocked_defense is Array:
		unlocked_defense = data.unlocked_defense.duplicate()
	if data.has("card_inventory") and data.card_inventory is Array:
		card_inventory.clear()
		for item in data.card_inventory:
			if item is Dictionary:
				card_inventory.append(refresh_stored_player(item.duplicate(true)))
	# Never strand cards from older unlimited-vault saves above the new capacity.
	if card_inventory.size() > vault_capacity():
		vault_capacity_bonus = ceili(float(card_inventory.size() - 20) / 10.0) * 10
	if data.has("veteran_cleared") and data.veteran_cleared is Array:
		veteran_cleared = data.veteran_cleared.duplicate()
	if data.has("coaches_owned") and data.coaches_owned is Array:
		coaches_owned = data.coaches_owned.duplicate()
	regular_wins = int(data.get("regular_wins", season_wins if season_phase == "regular" else regular_wins))
	regular_losses = int(data.get("regular_losses", season_losses if season_phase == "regular" else regular_losses))
	regular_games = int(data.get("regular_games", season_games if season_phase == "regular" else regular_games))
	if data.has("veteran_mission") and data.veteran_mission is Dictionary:
		veteran_mission = data.veteran_mission.duplicate(true)
	if bool(iap_receipts.get("national_%d" % active_save_slot, false)):
		national_unlocked = true
	closer_name = str(data.get("closer_name", closer_name))
	pending_path = str(data.get("pending_path", ""))
	pro_top2 = bool(data.get("pro_top2", false))
	difficulty_level = int(data.get("difficulty_level", 0))
	national_event = str(data.get("national_event", "jones_white"))
	national_progress = str(data.get("national_progress", national_event))
	last_pro_league = str(data.get("last_pro_league", current_league if current_league in ["SBL", "PLG", "TPBL"] else "SBL"))
	if bool(data.get("easl_pass", false)) or bool(iap_receipts.get("easl", false)):
		easl_pass = true
	if bool(data.get("jones_pass", false)) or bool(iap_receipts.get("jones", false)):
		jones_pass = true
	extra_event = str(data.get("extra_event", extra_event))
	if data.has("extra_runs") and data.extra_runs is Dictionary:
		extra_runs = data.extra_runs.duplicate(true)
		if not extra_event.is_empty():
			load_extra_run(extra_event)
	else:
		extra_entry = str(data.get("extra_entry", extra_entry))
		extra_wins = int(data.get("extra_wins", extra_wins))
		extra_queue.clear()
		if data.has("extra_queue") and data.extra_queue is Array:
			for item in data.extra_queue:
				if item is Dictionary:
					extra_queue.append(item)
		migrate_extra_runs_from_legacy()
	if data.has("extra_champions") and data.extra_champions is Dictionary:
		extra_champions = data.extra_champions.duplicate(true)
	last_home_points = int(data.get("last_home_points", 0))
	schedule_index = int(data.get("schedule_index", 0))
	if data.has("season_schedule") and data.season_schedule is Array:
		season_schedule = data.season_schedule.duplicate(true)
	if data.has("news_feed") and data.news_feed is Array:
		news_feed = data.news_feed.duplicate(true)
	if data.has("league_table") and data.league_table is Dictionary:
		league_table = data.league_table.duplicate(true)
	if data.has("last_box_sheet") and data.last_box_sheet is Array:
		last_box_sheet = data.last_box_sheet.duplicate(true)
	if data.has("last_match_gain") and data.last_match_gain is Dictionary:
		last_match_gain = data.last_match_gain.duplicate(true)
	refresh_opponents()
	refresh_tactic_unlocks()
	apply_salary_cap()
	var dup_n := compact_unique_owned()
	if dup_n > 0:
		last_event = "已清掉 %d 張重複卡，換成黃金。" % dup_n
	var scout_kept: Array[Dictionary] = []
	for item in gacha_candidates:
		if item is Dictionary and not is_locked_prize(item):
			if str(item.get("scout_offer_id", "")).is_empty():
				item["scout_offer_id"] = "%d:%d" % [scout_board_serial, scout_kept.size()]
			scout_kept.append(item)
	gacha_candidates = scout_kept
	ensure_bench()
	apply_combo_label()
	if season_phase == "regular" and (not data.has("season_schedule") or season_schedule.is_empty()):
		if season_schedule.is_empty():
			build_season_schedule()
		schedule_index = clampi(season_games, 0, maxi(0, season_schedule.size() - 1))
		apply_current_fixture()
	apply_designer_unlocks()
	restore_match_state(data)
	ensure_legacy_playoffs()
	if migrate_economy:
		save_game()
	if then_show:
		show_dashboard()
		if migrate_economy:
			call_deferred("flash_notice", "更新完成：原存檔已保留，補發資金 1,000 萬。SBL 一般球員年薪調整為 50～300 萬。")

func average_ovr() -> float:
	if team_players.is_empty():
		return 0.0
	var total := 0.0
	var n := mini(team_players.size(), gameday_limit())
	for i in n:
		total += float(effective_ovr(team_players[i], i))
	return total / float(n)

func playoff_series_line() -> String:
	var s := PlayoffSeries.user_series(playoff_state)
	if s.is_empty():
		return "季後賽"
	var high := str(s.a.team_id) == club_team_id()
	var w := int(s.wa if high else s.wb)
	var l := int(s.wb if high else s.wa)
	var title := "挑戰賽" if s.phase == "playin" or (current_league == "PLG" and s.phase == "semifinal") else ("冠軍賽" if s.phase == "final" else "四強")
	return "%s %d－%d · 先取 %d 勝" % [title, w, l, int(s.need)]

func show_playoff_bracket() -> void:
	var content := begin_screen("季後賽對戰樹", str(PlayoffSeries.rules(current_league).label) + " · 例行賽結束後進入系列賽", 4)
	content.add_child(callout("季後賽進度", "每張對戰卡會保留系列賽比分；點開可查看每場比分與主客場。", GOLD))
	var tree := HBoxContainer.new()
	tree.name = "PlayoffBracketTree"
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.add_theme_constant_override("separation", 10)
	content.add_child(tree)
	var round_names := ["四強／挑戰賽", "冠軍賽"]
	for r_idx in playoff_state.get("rounds", []).size():
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.custom_minimum_size = Vector2(210 if is_handheld() else 260, 0)
		col.add_theme_constant_override("separation", 8)
		col.add_child(label(round_names[mini(r_idx, round_names.size() - 1)], 16, GOLD if r_idx == 0 else ORANGE, true, HORIZONTAL_ALIGNMENT_CENTER))
		var round_series: Array = playoff_state.rounds[r_idx]
		for s in round_series:
			if not (s is Dictionary):
				continue
			col.add_child(playoff_series_tile(s))
		tree.add_child(col)
	if playoff_state.get("rounds", []).is_empty():
		content.add_child(callout("尚未產生季後賽", "完成例行賽後會依戰績自動建立對戰樹。", CYAN))
	pin_above_dock(content, action_button("返回首頁", Color("254e6b"), func(): show_dashboard(), Vector2(0, 44)))

func playoff_series_tile(s: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("0b1725e8"), GOLD.darkened(0.2), 12, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(padded(box, 8))
	var a: Dictionary = s.get("a", {})
	var b: Dictionary = s.get("b", {})
	var a_name := fictional_team_name(str(a.get("team_id", "")), str(a.get("name", "上位種子")))
	var b_name := fictional_team_name(str(b.get("team_id", "")), str(b.get("name", "下位種子")))
	box.add_child(label("%s  %d" % [a_name, int(s.get("wa", 0))], 15, TEXT, true))
	box.add_child(label("%s  %d" % [b_name, int(s.get("wb", 0))], 15, TEXT, true))
	box.add_child(label("先取 %d 勝%s" % [int(s.get("need", 3)), " · 已結束" if not s.get("winner", {}).is_empty() else ""], 11, MUTED))
	var games: Array = s.get("games", [])
	if not games.is_empty():
		var scores := PackedStringArray()
		for i in games.size():
			var g: Dictionary = games[i]
			scores.append("G%d %d:%d" % [i + 1, int(g.get("a", 0)), int(g.get("b", 0))])
		box.add_child(label(" · ".join(scores), 10, CYAN, false))
	return panel

func series_opponent_adjustment(s: Dictionary) -> void:
	if not s.winner.is_empty() or s.games.is_empty():
		return
	var high := str(s.a.team_id) == club_team_id()
	var last: Dictionary = s.games.back()
	var user_won := int(last.a) > int(last.b) if high else int(last.b) > int(last.a)
	if not user_won:
		return
	var rival: Dictionary = s.b if high else s.a
	var tid := str(rival.team_id)
	var style := opponent_tactic(tid).duplicate(true)
	var best := tactic_matchup_bonus(selected_tactic, str(style.defense))
	for entry in tactic_catalog("defense"):
		var candidate := str(entry.get("id", "人盯人"))
		var value := tactic_matchup_bonus(selected_tactic, candidate)
		if value < best:
			best = value
			style.defense = candidate
	var adjustments: Dictionary = playoff_state.get("adaptations", {})
	adjustments[tid] = style
	playoff_state["adaptations"] = adjustments

func create_playoffs() -> void:
	var ranked: Array = []
	for row in standings_rows():
		var team: Dictionary = row.duplicate(true)
		for rival in ranked_opponents():
			if str(rival.get("team_id")) == str(row.get("team_id")):
				team.merge(rival, true)
		if bool(row.get("self", false)):
			team["rating"] = average_ovr() + combo_team_bonus()
		ranked.append(team)
	playoff_state = PlayoffSeries.create(current_league, ranked, randi())
	advance_playoff_bracket()

func simulate_npc_series(s: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(playoff_state.get("rng_seed", 1)) + hash(str(s.id))
	while s.winner.is_empty():
		var a := opponent_match_profile(s.a, 0)
		var b := opponent_match_profile(s.b, 0)
		if not bool(s.neutral):
			if PlayoffSeries.high_home(s):
				a.rating += 2.0
			else:
				b.rating += 2.0
		var score := MatchSimulator.game(a, b, rng)
		PlayoffSeries.record(s, score[0], score[1])

func advance_playoff_bracket() -> void:
	for _round in 4:
		for s in PlayoffSeries.current(playoff_state):
			if str(s.a.team_id) != club_team_id() and str(s.b.team_id) != club_team_id():
				simulate_npc_series(s)
		var mine := PlayoffSeries.user_series(playoff_state)
		if not mine.is_empty() and mine.winner.is_empty():
			season_phase = str(mine.phase)
			league_match_opponent() # Set the next scheduled home/away designation.
			last_event = playoff_series_line()
			return
		if not PlayoffSeries.advance(playoff_state):
			break
	var champion: Dictionary = playoff_state.get("champion", {})
	if str(champion.get("team_id", "")) == club_team_id():
		season_phase = "champion"
		championships[current_league] = true
		last_event = "%s 系列賽冠軍到手！" % current_league
		unlock_after_title()
	else:
		open_offseason("本季結束。季後賽採系列賽，已保留每場紀錄。可參加選秀並準備下一季。")

func ensure_legacy_playoffs() -> void:
	if not playoff_state.is_empty() or season_phase not in ["semifinal", "final"]:
		return
	# An old save already earned this round. Preserve that qualification and any pending game.
	var opponent: Dictionary = last_opponent.duplicate(true) if match_rewards_pending else league_match_opponent().duplicate(true)
	var mine := {"team_id":"club", "name":club_name, "rating":average_ovr(), "seed":1}
	opponent["seed"] = 2
	var r := PlayoffSeries.rules(current_league)
	var first := PlayoffSeries.series("legacy", season_phase, mine, opponent, int(r.final if season_phase == "final" else r.semi), bool(r.neutral))
	var ranked: Array = [mine, opponent]
	var round_series: Array = [first]
	for team in ranked_opponents():
		if str(team.get("team_id")) == str(opponent.get("team_id")):
			continue
		var other: Dictionary = team.duplicate(true)
		other["seed"] = ranked.size() + 1
		ranked.append(other)
		if ranked.size() >= 4:
			break
	if season_phase == "semifinal" and current_league != "PLG" and ranked.size() >= 4:
		round_series.append(PlayoffSeries.series("legacy_other", "semifinal", ranked[2], ranked[3], int(r.semi), bool(r.neutral)))
	# PLG legacy semifinal winners face an independent finalist, not themselves.
	if current_league == "PLG" and season_phase == "semifinal" and ranked.size() >= 3:
		var finalist: Dictionary = ranked[2].duplicate(true)
		finalist["seed"] = 1
		first.a.seed = 2
		first.b.seed = 3
		ranked[0] = finalist
	playoff_state = {"version":1, "league":current_league, "seeds":ranked, "rounds":[round_series], "round":0, "rng_seed":randi(), "champion":{}, "legacy":true}
	# Do not replace an in-flight game's saved home court.
	if not match_rewards_pending:
		league_match_opponent()

func match_period_count() -> int:
	return maxi(4, quarter_scores[0].size()) if quarter_scores.size() == 2 else 4

func match_visible_period_count() -> int:
	var next := reveal_quarter + 1 if reveal_quarter >= 4 and last_score[0] == last_score[1] else reveal_quarter
	return mini(match_period_count(), maxi(4, next))

func period_label(index: int) -> String:
	return "Q%d" % (index + 1) if index < 4 else "OT%d" % (index - 3)

func active_match_players(q: int) -> Array:
	var result: Array = []
	var slot := mini(q, 3)
	if slot < last_match_oncourt.size():
		for index in last_match_oncourt[slot]:
			if int(index) >= 0 and int(index) < team_players.size():
				result.append(team_players[int(index)])
	if result.is_empty():
		result = team_players.slice(0, mini(5, team_players.size()))
	return result

func lineup_skill_profile(players: Array, attack_tactic: String, defense_tactic: String) -> Dictionary:
	var result := {"offense":0.0, "defense":0.0, "q4":0.0, "chemistry":0.0, "names":[]}
	for player in players:
		if not player_skill_unlocked(player):
			continue
		var skill := str(player.get("skill_id", ""))
		var profile := skill_profile(skill)
		for key in ["offense", "defense", "q4", "chemistry"]:
			result[key] += float(profile.get(key, 0)) / maxf(1, players.size())
		if attack_tactic == "快節奏轉換" and skill in ["three_and_d", "transition", "volume_scorer"]:
			result.offense += 0.08
		if attack_tactic == "擋拆進攻" and skill in ["floor_general", "screen_hub", "playmaker"]:
			result.offense += 0.08
		if defense_tactic == "全場壓迫" and skill in ["lockdown", "hustle", "transition"]:
			result.defense += 0.08
	# Prevent stacking five strong skills from overwhelming OVR and tactics.
	result.offense = clampf(result.offense, -SKILL_TEAM_OFFENSE_CAP, SKILL_TEAM_OFFENSE_CAP)
	result.defense = clampf(result.defense, -SKILL_TEAM_DEFENSE_CAP, SKILL_TEAM_DEFENSE_CAP)
	result.q4 = clampf(result.q4, -SKILL_TEAM_Q4_CAP, SKILL_TEAM_Q4_CAP)
	return result

func opponent_match_profile(opponent: Dictionary, q: int) -> Dictionary:
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	var starters := opponent_starting_five(opponent)
	var roster: Array = opponent_club(opponent).get("players", opponent.get("players", []))
	var active: Array = starters.duplicate()
	if q in [1, 2] and roster.size() > 5:
		var bench: Array = []
		for raw in roster:
			var used := false
			for player in starters:
				if str(player.get("name")) == str(raw.get("name")):
					used = true
			if not used:
				bench.append(to_game_player(raw))
		for i in mini(2 if q == 1 else 3, bench.size()):
			active[i] = bench[i]
	var skills := lineup_skill_profile(active, str(style.offense), str(style.defense))
	var rating := float(opponent.get("rating", 75))
	var starter_rating := 0.0
	var active_rating := 0.0
	for p in starters:
		starter_rating += float(p.get("ovr", 75)) / maxf(1, starters.size())
	for p in active:
		active_rating += float(p.get("ovr", 75)) / maxf(1, active.size())
	rating += active_rating - starter_rating
	# Equal reference chemistry and coaching; no one-sided permanent boost.
	return {"rating":rating, "offense":skills.offense + 0.04, "defense":skills.defense + 0.02, "pace":24 if style.offense == "快節奏轉換" else 22, "three_rate":0.40 if style.offense in ["快節奏轉換", "電梯門戰術"] else 0.34, "active":active, "attack":style.offense, "cover":style.defense}

func quarter_match_profiles(q: int) -> Array:
	var opponent: Dictionary = last_opponent if not last_opponent.is_empty() else current_match_opponent()
	var theirs := opponent_match_profile(opponent, mini(q, 3))
	var active := active_match_players(q)
	var rating := 0.0
	for player in active:
		rating += float(effective_ovr(player, team_players.find(player))) / maxf(1, active.size())
	var skills := lineup_skill_profile(active, selected_tactic, selected_defense)
	var coach := coach_data(coach_id)
	var style := opponent_tactic(str(opponent.get("team_id", "")))
	var attack_edge := tactic_matchup_bonus(selected_tactic, str(style.defense))
	var defense_edge := defense_matchup_bonus(selected_defense, str(style.offense))
	var mine := {"rating":rating + combo_team_bonus() + (chemistry - 50) * 0.025 - roster_depth_penalty_percent() * 0.12, "offense":skills.offense + float(coach.get("offense", 0)), "defense":skills.defense + float(coach.get("defense", 0)), "pace":24 if selected_tactic == "快節奏轉換" else 22, "three_rate":0.40 if selected_tactic in ["快節奏轉換", "電梯門戰術"] else 0.34}
	mine.offense += attack_edge * 0.20
	theirs.defense -= attack_edge * 0.20
	mine.defense += defense_edge * 0.20
	theirs.offense -= defense_edge * 0.20
	var neutral := not extra_match and current_league == "SBL" and season_phase in ["semifinal", "final"]
	if not neutral:
		if is_home_game:
			mine.rating += 2.0
		else:
			theirs.rating += 2.0
	return [mine, theirs]

func resource_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if FileAccess.file_exists(path):
		return true
	var disk := ProjectSettings.globalize_path(path)
	if disk != path and FileAccess.file_exists(disk):
		return true
	return ResourceLoader.exists(path)

func load_svg_tex(path: String, px := 128) -> Texture2D:
	if path.is_empty() or _tex_miss.has(path):
		return null
	if _tex_cache.has(path) and _tex_cache[path] is Texture2D:
		return _tex_cache[path]
	var disk := ProjectSettings.globalize_path(path)
	var baked = load(path) if ResourceLoader.exists(path) else null
	if baked is Texture2D:
		_tex_cache[path] = baked
		return baked
	if not FileAccess.file_exists(disk) and not FileAccess.file_exists(path):
		_tex_miss[path] = true
		return null
	var file := FileAccess.open(disk, FileAccess.READ)
	if file == null:
		_tex_miss[path] = true
		return null
	var svg := file.get_as_text()
	var img := Image.new()
	var scale := maxf(1.0, float(px) / 24.0)
	if img.load_svg_from_string(svg, scale) != OK:
		_tex_miss[path] = true
		return null
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex

func load_png_tex(path: String) -> Texture2D:
	if path.is_empty() or _tex_miss.has(path):
		return null
	if _tex_cache.has(path) and _tex_cache[path] is Texture2D:
		return _tex_cache[path]
	if ResourceLoader.exists(path):
		var baked = load(path)
		if baked is Texture2D:
			_tex_cache[path] = baked
			return baked
	var disk := ProjectSettings.globalize_path(path)
	var from_disk := disk if FileAccess.file_exists(disk) else (path if FileAccess.file_exists(path) else "")
	if from_disk.is_empty():
		_tex_miss[path] = true
		return null
	var cap := 768
	if path.contains("/arena") or path.contains("half_court") or path.contains("game_logo"):
		cap = 1024
	elif path.contains("/cards/") or path.contains("hero_") or path.contains("skill_cutin"):
		cap = 1024
	elif path.contains("/store/") or path.contains("/hud/"):
		cap = 768
	var tex := _texture_from_disk(from_disk, "", cap)
	if tex != null:
		_tex_cache[path] = tex
		return tex
	_tex_miss[path] = true
	return tex

func _image_magic(disk: String) -> String:
	var file := FileAccess.open(disk, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(16)
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		return "jpg"
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		return "png"
	if bytes.size() >= 12 and bytes[0] == 0x52 and bytes[8] == 0x57:
		return "webp"
	return ""

func _texture_from_disk(disk: String, _magic := "", max_side := 768) -> Texture2D:
	var magic := _image_magic(disk)
	if magic.is_empty():
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if magic == "png":
		err = img.load(disk)
	elif magic == "jpg" or magic == "webp":
		var file := FileAccess.open(disk, FileAccess.READ)
		if file == null:
			return null
		var bytes := file.get_buffer(mini(file.get_length(), 8_000_000))
		if magic == "jpg":
			err = img.load_jpg_from_buffer(bytes)
		else:
			err = img.load_webp_from_buffer(bytes)
	if err != OK or img.get_width() < 2 or img.get_height() < 2:
		return null
	if max_side > 0 and (img.get_width() > max_side or img.get_height() > max_side):
		var scale := minf(float(max_side) / float(img.get_width()), float(max_side) / float(img.get_height()))
		img.resize(maxi(2, int(round(float(img.get_width()) * scale))), maxi(2, int(round(float(img.get_height()) * scale))), Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)

func manga_path_for(path: String) -> String:
	if path.is_empty() or not path.begins_with("res://assets/"):
		return ""
	var mapped := path.replace("res://assets/images/", "res://assets/manga/")
	mapped = mapped.replace("res://assets/players/", "res://assets/manga/players/")
	mapped = mapped.replace("res://assets/portraits/", "res://assets/manga/portraits/")
	if mapped == path:
		return ""
	return mapped.get_basename() + ".png"

func apply_manga_filter(_rect: TextureRect, _source_path: String) -> void:
	return

func player_texture(player: Dictionary) -> Texture2D:
	return player_image(player).get("tex")

func player_image(player: Dictionary) -> Dictionary:
	if bool(player.get("draft_2026", false)):
		return {"tex": null, "path": ""}
	var styled := unique_portrait_path(player)
	if not styled.is_empty():
		var hero := load_png_tex(styled)
		if hero != null:
			return {"tex": hero, "path": styled}
	return {"tex": null, "path": ""}

func _portrait_pool() -> Array[String]:
	var pool: Array[String] = []
	for path in STYLIZED_ART:
		if resource_exists(path) and not pool.has(path):
			pool.append(path)
	return pool

func _pos_hero_path(player: Dictionary) -> String:
	var pos := str(player.get("pos", player.get("position", "SG")))
	var by_pos := {
		"PG": "res://assets/art/hero_pg.png",
		"SG": "res://assets/art/hero_sg.png",
		"SF": "res://assets/art/hero_sf.png",
		"PF": "res://assets/art/hero_pf.png",
		"C": "res://assets/art/hero_c.png",
	}
	var keyed: String = str(by_pos.get(pos, ""))
	if not keyed.is_empty() and resource_exists(keyed):
		return keyed
	return ""

func unique_portrait_path(player: Dictionary) -> String:
	# Shared illustrative artwork, not a claim about a real player's likeness.
	# Never reassign an existing player's face when the roster or shop changes.
	var pool := _portrait_pool()
	if pool.is_empty():
		return ""
	var key := player_identity_key(player)
	if key.is_empty():
		key = str(player.get("name", player.get("id", "")))
	return pool[absi(key.hash()) % pool.size()]

func stylized_portrait_path(player: Dictionary) -> String:
	return unique_portrait_path(player)

func fallback_portrait_path(player: Dictionary) -> String:
	var fallbacks := STYLIZED_ART.duplicate()
	if fallbacks.is_empty():
		return ""
	var key := str(player.get("name", player.get("id", "")))
	var index := absi(key.hash()) % fallbacks.size()
	for i in fallbacks.size():
		var candidate: String = fallbacks[(index + i) % fallbacks.size()]
		if resource_exists(candidate):
			return candidate
	return ""

func head_texture(player: Dictionary) -> Texture2D:
	return bust_texture(player)

func nameplate_fallback(player: Dictionary) -> Control:
	var ovr := int(player.get("ovr", 70))
	var rim := ovr_frame_color(ovr)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("1a1208"), rim, 10, 1))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	panel.add_child(padded(box, 6))
	box.add_child(label(str(player.get("pos", player.get("position", "G"))), 11, rim, true, HORIZONTAL_ALIGNMENT_CENTER))
	var mark := label(str(player.get("name", "球員")), 16, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	mark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(mark)
	return panel

func simple_bust(player: Dictionary, side := 36) -> Control:
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(side, side)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := bust_texture(player)
	if tex != null:
		art.texture = tex
		return art
	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(side, side)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_stylebox_override("panel", panel_style(Color("1a1208"), player_frame_color(player), 8, 1))
	var lab := plain_label(str(player.get("pos", "G")), clampi(int(side * 0.38), 10, 16), TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mark.add_child(lab)
	return mark

func player_photo_rect(player: Dictionary, box_size: Vector2) -> Control:
	var rim := player_frame_color(player)
	var side := maxi(36, int(mini(box_size.x, box_size.y)))
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(side, side)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel", invisible_style())
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(side, side)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.clip_contents = true
	frame.add_child(inner)
	var plate := ColorRect.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.color = Color(0.06, 0.08, 0.12, 1)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(plate)
	var tex := blended_card_portrait(player)
	if tex != null:
		inner.add_child(card_bust_layer(tex))
	elif side >= 52:
		var fallback := VBoxContainer.new()
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.offset_left = 8
		fallback.offset_top = 10
		fallback.offset_right = -8
		fallback.offset_bottom = -10
		fallback.alignment = BoxContainer.ALIGNMENT_CENTER
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.add_theme_constant_override("separation", 2)
		inner.add_child(fallback)
		fallback.add_child(plain_label(str(player.get("pos", player.get("position", "G"))), 11, rim, true, HORIZONTAL_ALIGNMENT_CENTER))
		var who := plain_label(str(player.get("name", "球員")), 14, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fallback.add_child(who)
	var frame_tex := card_frame_for(player_tier_key(player))
	if frame_tex != null:
		inner.add_child(card_frame_layer(frame_tex, card_frame_tint(player_tier_key(player))))
	var origin := origin_id(player)
	if not origin.is_empty() and player_tier_key(player) != "diamond":
		var mark := team_logo_rect(origin, 16, str(player.get("name", "")))
		mark.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		mark.anchor_top = 0.72
		mark.offset_left = -8
		mark.offset_top = 0
		mark.offset_right = 8
		mark.offset_bottom = -4
		inner.add_child(mark)
	return frame

func player_portrait(player: Dictionary, box_size: Vector2) -> Control:
	return player_photo_rect(player, box_size)

func card_art(player: Dictionary) -> Control:
	return player_photo_rect(player, Vector2(88, 112))

func bust_from_tex(tex: Texture2D, source_path := "", salt := 0) -> Texture2D:
	if tex == null:
		return null
	var key := "%s#%s#%d" % [source_path, str(tex.get_rid()), absi(salt) % 5]
	if _bust_cache.has(key) and _bust_cache[key] is Texture2D:
		return _bust_cache[key]
	var w := tex.get_width()
	var h := tex.get_height()
	if w <= 8 or h <= 8:
		_bust_cache[key] = tex
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var framed := source_path.contains("hero_")
	if framed:
		var inset := int(round(float(w) * 0.20))
		var side := clampi(int(round(float(w) * 0.50)), 32, mini(w - inset * 2, h))
		var x := int(round(float(w - side) * 0.5))
		var y_ratio := 0.06 + float(absi(salt) % 5) * 0.03
		var y := clampi(int(round(float(h) * y_ratio)), 0, h - side)
		atlas.region = Rect2(x, y, side, side)
	elif h > w * 1.15:
		var side2 := mini(w, int(round(float(w) * 0.90)))
		var x2 := int(round(float(w - side2) * 0.5))
		var y2 := clampi(int(round(float(h) * 0.05)), 0, h - side2)
		atlas.region = Rect2(x2, y2, side2, side2)
	else:
		var side3 := mini(w, h)
		atlas.region = Rect2(int(round(float(w - side3) * 0.5)), 0, side3, side3)
	_bust_cache[key] = atlas
	return atlas

func bust_texture(player: Dictionary) -> Texture2D:
	var data: Dictionary = player_image(player)
	var salt := absi(str(player.get("name", player.get("id", ""))).hash())
	return bust_from_tex(data.get("tex"), str(data.get("path", "")), salt)

func generated_portrait_for(player: Dictionary) -> Texture2D:
	# Registration identity is authoritative. Never infer a real player's appearance
	# from a Chinese name, nationality, team, or roster order. Until a foreign
	# player's visual profile has been checked against an official source, show the
	# same faceless/no-skin-tone silhouette instead of guessing Black or White.
	if is_foreigner(player) or is_foreign_student(player):
		return load_png_tex("res://assets/art/player_portraits/foreign_unverified_silhouette_v1.png")
	var pool: Array[String] = []
	for i in range(1, 21):
		var path := "res://assets/art/player_portraits/prospect_%02d.png" % i
		if resource_exists(path):
			pool.append(path)
	if pool.is_empty():
		return null
	var tid := str(player.get("origin_team_id", ""))
	if tid.is_empty():
		tid = team_id_from_display_name(str(player.get("team", "")))
	# This reviewed subset contains local-player illustrations only. The team crest
	# is composited separately on the chest; foreign-looking portrait sources are
	# never assigned to players registered as local.
	var portrait_variants := {
		"fubon": [1, 10, 17],
		"pilots": [4, 12, 20],
		"ghosthawks": [7, 17, 20],
		"yankey": [6, 14],
		"dreamers": [6, 14, 19],
		"lioneers": [12, 19, 20],
		"aquas": [6, 14],
		"dea": [4, 12, 20],
		"kings": [4, 12, 20],
		"mars": [7, 17, 20],
		"leopards": [6, 14, 19],
		"sbl_pure": [12, 19, 20],
		"sbl_kites": [6, 14, 19],
		"sbl_bank": [6, 14, 19],
		"sbl_beer": [6, 14, 19],
		"sbl_yulon": [1, 10, 17],
	}
	var variants: Array = portrait_variants.get(tid, [1, 4, 6, 7, 10, 12, 14, 17, 19, 20])
	var identity := str(player.get("id", ""))
	var suffix := identity.get_slice("_", identity.get_slice_count("_") - 1)
	var pick := absi(str(player.get("name", identity)).hash())
	if suffix.is_valid_int():
		var roster_number := int(suffix)
		# Offset every completed pass through the palette so separated roster
		# numbers do not repeatedly land on the same portrait.
		pick = roster_number + floori(float(roster_number) / float(variants.size()))
	var portrait_number: int = int(variants[pick % variants.size()])
	return load_png_tex("res://assets/art/player_portraits/prospect_%02d.png" % portrait_number)

func blended_card_portrait(player: Dictionary) -> Texture2D:
	# New generated portraits rotate through twenty stable faces/poses; saved player
	# data and original assets remain untouched. The chest logo is composited by
	# PlayerCardVisual so portrait variety remains independent of the club crest.
	# A verified, player-specific roster photo always wins. Previously every
	# foreign card was forced through the silhouette path even when its matched
	# official photo was already bundled in the project.
	var verified_photo := official_photo_path(player)
	if not verified_photo.is_empty():
		var verified_tex := load_png_tex(verified_photo)
		if verified_tex != null:
			return verified_tex
	if bool(player.get("draft_2026", false)) or bool(player.get("rotate_generated_portrait", true)):
		var generated := generated_portrait_for(player)
		if generated != null:
			return generated
	var data: Dictionary = player_image(player)
	var tex: Texture2D = data.get("tex")
	if tex == null:
		return generated_portrait_for(player)
	var source_path := str(data.get("path", ""))
	var salt := absi(str(player.get("name", player.get("id", ""))).hash())
	var key := "%s#blend6#%d" % [source_path, salt % 3]
	if _bust_cache.has(key) and _bust_cache[key] is Texture2D:
		return _bust_cache[key]
	var img := tex.get_image()
	if img == null or img.get_width() < 8 or img.get_height() < 8:
		_bust_cache[key] = tex
		return tex
	var w := img.get_width()
	var h := img.get_height()
	var framed := source_path.contains("hero_")
	var x := 0
	var y := 0
	var cw := w
	var ch := h
	if framed:
		var inset_x := int(round(float(w) * 0.13))
		x = inset_x
		y = int(round(float(h) * (0.08 + float(salt % 3) * 0.006)))
		cw = maxi(32, w - inset_x * 2)
		ch = clampi(int(round(float(h) * 0.56)), 32, h - y)
	else:
		cw = maxi(32, int(round(float(w) * 0.86)))
		x = int(round(float(w - cw) * 0.5))
		y = clampi(int(round(float(h) * 0.04)), 0, h - 32)
		ch = clampi(int(round(float(h) * 0.78)), 32, h - y)
	img = img.get_region(Rect2i(x, y, cw, ch))
	if img.get_width() > 280:
		var nh := maxi(2, int(round(280.0 * float(img.get_height()) / float(img.get_width()))))
		img.resize(280, nh, Image.INTERPOLATE_BILINEAR)
	_fade_portrait_into_frame(img)
	var out := ImageTexture.create_from_image(img)
	_bust_cache[key] = out
	return out

func _fade_portrait_into_frame(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var top_band := maxi(1, int(round(float(h) * 0.04)))
	var bot_start := int(round(float(h) * 0.82))
	var denom_x := float(maxi(1, w - 1))
	var denom_y := float(maxi(1, h - bot_start))
	for y in h:
		var fy := 1.0
		if y < top_band:
			fy = float(y) / float(top_band)
		elif y > bot_start:
			var t := float(y - bot_start) / denom_y
			fy = clampf(1.0 - t, 0.0, 1.0)
			fy = fy * fy * (3.0 - 2.0 * fy)
		for x in w:
			var nx := float(x) / denom_x
			var fx := sin(PI * nx)
			fx = clampf(0.86 + 0.14 * fx, 0.0, 1.0)
			var idx := (y * w + x) * 4 + 3
			data[idx] = int(round(float(data[idx]) * clampf(fx * fy, 0.0, 1.0)))
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)

func player_show_card(player: Dictionary, _badge: String, detail: String, _accent: Color, selected: bool, action: Callable) -> Control:
	var card := lobby_player_card(player, false, -1, false, market_card_width(), action, -1, detail)
	if selected:
		card.modulate = Color(1.08, 1.04, 0.84)
	return card

func show_owned_player(index: int) -> void:
	if index < 0 or index >= team_players.size():
		return
	selected_foundation = index
	var return_roster := active_menu == "roster"
	var return_match := active_menu == "match"
	var editing := roster_editing
	show_player_sheet(team_players[index], func():
		if return_match:
			show_match_prep()
		elif return_roster:
			show_roster(editing)
		elif not return_stack.is_empty():
			go_return_page()
		else:
			show_dashboard()
	, Callable(), "", index)

func show_player_sheet(player: Dictionary, back: Callable, confirm := Callable(), confirm_label := "", owned_index := -1, free_signing := false) -> void:
	var card: Dictionary = to_game_player(player)
	if owned_index < 0:
		owned_index = roster_index_of(card)
	if back.is_valid():
		return_stack.append(back)
	var phone := compact_phone()
	var content := begin_screen(str(card.get("name", "球員")), "%s · 基礎 OVR %d" % [position_mark(card), int(card.get("ovr", 70))], 4, false)
	var layout: BoxContainer = HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", UI_PLAYER_SHEET_GAP_PHONE if phone else UI_PLAYER_SHEET_GAP_DESKTOP)
	content.add_child(layout)
	var face_box := UI_PLAYER_FACE_PHONE if phone else UI_PLAYER_FACE_DESKTOP
	var face := player_photo_rect(card, face_box)
	face.custom_minimum_size = face_box
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	face.pivot_offset = face_box * 0.5
	face.scale = Vector2(0.94, 0.94) if phone else Vector2(0.96, 0.96)
	layout.add_child(face)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6 if phone else 8)
	layout.add_child(info)
	info.add_child(polish_title(label(str(card.get("name", "球員")), 24 if phone else 28, TEXT, true)))
	var foreign := is_foreigner(card)
	if position_data_missing(card):
		info.add_child(wrap_label("位置尚未收錄；目前對戰暫用 %s，待補正。" % "/".join(player_pos_list(card)), 16, ORANGE, true))
	else:
		info.add_child(pos_chip(card))
	info.add_child(label("%s · 遊戲年薪 $%d 萬" % [identity_label(card), int(float(card.get("salary_million", published_salary(card))))], 16, GOLD, true))
	var signing_block := can_sign_free_agent(card) if free_signing else ""
	if free_signing:
		var payroll := roster_salary()
		var after := payroll + published_salary(card)
		var preview := wrap_label("資金 $%d 萬 · 簽約費 $%d 萬\n薪資：$%d → $%d／$%d 萬\n簽約只扣資金，不扣黃金或球探點。" % [budget_million, free_agent_signing_fee(card), payroll, after, salary_cap], 16, CYAN if signing_block.is_empty() else ORANGE, true)
		preview.name = "FreeAgentPayrollPreview"
		info.add_child(preview)
		if not signing_block.is_empty():
			info.add_child(wrap_label(signing_block, 14, ORANGE, true))
	if foreign:
		info.add_child(wrap_label(foreigner_detail_line(), 13, ORANGE, true))
	elif is_foreign_student(card):
		info.add_child(wrap_label(foreign_student_detail_line(), 13, PURPLE, true))
	var aka := player_aka_line(str(card.get("name", "")))
	if not aka.is_empty():
		info.add_child(wrap_label(aka, 13, MUTED, false))
	var trained_count := int(card.get("training_sessions", 0))
	var base_ovr := maxi(50, int(card.get("ovr", 70)) - trained_count)
	var team_bonus := combo_team_bonus() + roster_aura_ovr()
	var total_ovr := int(card.get("ovr", 70)) + roster_aura_ovr()
	info.add_child(wrap_label("本土／外援：%s · 年薪 $%d 萬" % [identity_label(card), int(float(card.get("salary_million", published_salary(card))) )], 16, GOLD, true))
	info.add_child(wrap_label("基礎 OVR %d · 特訓 +%d · 隊伍加成 +%d · 目前 OVR %d" % [base_ovr, trained_count, team_bonus, total_ovr], 16, CYAN, true))
	if owned_index >= 0:
		info.add_child(wrap_label("上場 OVR %d（含位置修正）" % effective_ovr(card, owned_index), 18, CYAN))
	info.add_child(wrap_label("插畫為示意，非本人照片；OVR 與薪資為遊戲設定。", 18, MUTED))
	var skill := str(card.get("skill_description", ""))
	if skill.is_empty():
		skill = weekly_stat_line(card)
	info.add_child(wrap_label("%s  %s：%s" % [skill_position_badge(card), str(card.get("skill_name", "即戰力")), skill], 14, MUTED))
	var has_stats := card.has("ppg") or card.has("rpg") or card.has("apg")
	info.add_child(wrap_label("收錄數據（非即時）：" + weekly_stat_line(card).replace("這季數據：", "") if has_stats else "尚無收錄賽季數據", 18, MUTED))
	if has_stats and not str(card.get("source", "")).is_empty():
		info.add_child(wrap_label("來源：" + str(card.get("source")), 18, MUTED))
	if owned_index >= 0:
		info.add_child(owned_club_stats_block(team_players[owned_index] if owned_index < team_players.size() else card))
	if owned_index >= 0:
		var sessions := int(card.get("training_sessions", 0))
		info.add_child(label("已特訓 %d／%d 次 · 上場 %d／3 場 · 特訓點 %d" % [sessions, TRAINING_MAX_SESSIONS, int(card.get("match_appearances", 0)), training_points], 12 if phone else 13, MUTED))
		var train_txt := "養成特訓 +1 OVR"
		# Training is paid with training points and club funds only.  Use the
		# regular action style here so the gold themed button cannot be mistaken
		# for a gold currency purchase.
		var train_button := action_button(train_txt + "（特訓點＋資金）", GREEN, func():
			var before_pts := training_points
			apply_player_training(owned_index, false)
			if training_points != before_pts and owned_index < team_players.size():
				show_owned_player(owned_index)
		)
		train_button.disabled = sessions >= TRAINING_MAX_SESSIONS or int(card.get("match_appearances", 0)) < 3 or training_points < 1 or budget_million < 20
		content.add_child(train_button)
		if sessions >= TRAINING_MAX_SESSIONS and has_secondary_position(card):
			var unlocked := bool(card.get("secondary_position_unlocked", false))
			var breakthrough := action_button("副位置：%s" % ("已解鎖" if unlocked else "突破解鎖"), Color("4b3b69"), func():
				unlock_secondary_position(owned_index)
			, Vector2(0, 42))
			breakthrough.disabled = unlocked
			breakthrough.tooltip_text = "完成特訓 +5 後解鎖第二位置" if not unlocked else "副位置已解鎖"
			content.add_child(breakthrough)
	var sheet_bar := HBoxContainer.new()
	sheet_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_bar.add_theme_constant_override("separation", 4 if phone else 6)
	if confirm.is_valid() and not confirm_label.is_empty():
		var confirm_btn := action_button(confirm_label, ORANGE, confirm, Vector2(0, 48))
		confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if free_signing:
			confirm_btn.name = "FreeAgentSignButton"
			confirm_btn.disabled = not signing_block.is_empty()
		sheet_bar.add_child(confirm_btn)
	else:
		var vault_index := inventory_index_of(card)
		if vault_index >= 0:
			var login_btn := action_button("登錄球隊", ORANGE, func(): place_from_vault(vault_index), Vector2(0, 48))
			login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sheet_bar.add_child(login_btn)
	if owned_index >= 0 and team_players.size() > minimum_roster_to_play():
		var stash_btn := action_button("放入保管箱", Color("254e6b"), func(): move_roster_to_vault(owned_index), Vector2(0, 44))
		stash_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sheet_bar.add_child(stash_btn)
	var share_card := card.duplicate(true)
	sheet_bar.add_child(action_button("分享卡片", GOLD, func(): show_share_sheet(player_share_text(share_card, false), share_card), Vector2(160, 80 if is_handheld() else 48)))
	pin_above_dock(content, sheet_bar)
	play_sfx("pack")
	var pop := face.create_tween()
	pop.set_ease(Tween.EASE_OUT)
	pop.set_trans(Tween.TRANS_SINE)
	pop.tween_property(face, "scale", Vector2.ONE, 0.22)

func animate_press(target: Control, pressed: bool) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	var old: Tween = target.get_meta("press_tween") if target.has_meta("press_tween") else null
	if old != null and old.is_valid():
		old.kill()
	target.pivot_offset = target.size * 0.5
	var tw := target.create_tween()
	target.set_meta("press_tween", tw)
	tw.tween_property(target, "scale", Vector2(0.96, 0.96) if pressed else Vector2.ONE, 0.10)

func bind_press_juice(target: Control, hit: BaseButton) -> void:
	hit.button_down.connect(func(): animate_press(target, true))
	hit.button_up.connect(func(): animate_press(target, false))
	hit.mouse_exited.connect(func(): animate_press(target, false))
	hit.focus_exited.connect(func(): animate_press(target, false))

func opponent_face(opponent: Dictionary) -> Dictionary:
	var mine := ""
	if not team_players.is_empty():
		mine = str(team_players[0].get("name", ""))
	var team_id := str(opponent.get("team_id", ""))
	for team in league_teams:
		if str(team.get("id", "")) != team_id:
			continue
		for raw in team.get("players", []):
			if not (raw is Dictionary):
				continue
			var star := to_game_player(raw)
			if str(star.get("name", "")) != mine:
				return star
	if not public_players.is_empty():
		for raw in public_players:
			var star := to_game_player(raw)
			if str(star.get("name", "")) != mine:
				return star
	if not team_players.is_empty():
		return team_players[0]
	return {}

func current_quarter_skill_line() -> String:
	if reveal_quarter > 0 and reveal_quarter <= quarter_stories.size():
		return str(quarter_stories[reveal_quarter - 1])
	var triggered: Array = current_skill_modifiers.get("triggered", [])
	for item in triggered:
		var text_value := str(item)
		if text_value.begins_with("Q%d" % reveal_quarter):
			return text_value
	return "本節膠著纏鬥"

func player_named(player_name: String) -> Dictionary:
	for player in team_players:
		if str(player.get("name", "")) == player_name:
			return player
	if team_players.is_empty():
		return {}
	return team_players[0]

func mvp_result_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("111d2aed"), ORANGE.darkened(0.25), 16, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(padded(row, 8 if is_handheld() else 12))
	var shot := card_art(player_named(last_mvp))
	shot.custom_minimum_size = Vector2(64, 82) if is_handheld() else Vector2(88, 112)
	row.add_child(shot)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	row.add_child(box)
	box.add_child(label("本場 MVP", 15, ORANGE, true))
	box.add_child(label(last_mvp, 20, TEXT, true))
	box.add_child(label("%d PTS · %d REB · %d AST" % [last_box.pts, last_box.reb, last_box.ast], 14, GOLD, true))
	return panel

func live_card_button(player: Dictionary, index: int, action: Callable) -> Control:
	return player_show_card(player, str(player.get("pos", "G")), weekly_stat_line(player), ovr_frame_color(int(player.get("ovr", 75))), false, func(): action.call(index))

func player_card_button(player: Dictionary, index: int, chosen: bool, action: Callable) -> Control:
	var border := ovr_frame_color(int(player.get("ovr", 70)))
	var badge := str(player.get("pos", "G"))
	return player_show_card(player, badge, "OVR %d" % int(player.get("ovr", 70)), border, chosen, func(): action.call(index))

func court_player(player: Dictionary) -> PanelContainer:
	var border := ovr_frame_color(int(player.get("ovr", 70)))
	var chip := PanelContainer.new()
	chip.clip_contents = false
	chip.add_theme_stylebox_override("panel", panel_style(Color("070b12f5"), border, 10, 2))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	chip.add_child(padded(box, 6))
	box.add_child(label(str(player.get("pos", "G")), 10, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(label(str(player.get("name", "球員")), 13, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(label("OVR %d" % int(player.get("ovr", 70)), 10, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	return chip

func tactic_column(title: String, options: Array, current: String, accent: Color, offense: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("111d2aed"), accent.darkened(0.2), 20, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(padded(box, 18))
	box.add_child(label(title, 22, TEXT, true))
	box.add_child(label("點一套本場要用的打法", 12, MUTED))
	for option in options:
		var chosen: bool = str(option) == current
		var b := action_button(("●  " if chosen else "○  ") + option, accent if chosen else Color("26384b"), func(value = option, is_offense = offense):
			if is_offense:
				selected_tactic = value
			else:
				selected_defense = value
			save_game()
			show_tactics()
		, Vector2(0, 58))
		box.add_child(b)
	box.add_child(callout("戰術效果", tactic_description(current), accent))
	return panel

func tactic_description(tactic: String) -> String:
	var blurb := tactic_blurb(tactic)
	if not blurb.is_empty():
		return "%s %s" % [blurb.get("how", ""), blurb.get("vs", "")]
	match tactic:
		"快節奏轉換": return "轉換進攻：守下球立刻推。對手區域時外線空檔↑，對手全場壓迫時失誤↑。"
		"擋拆進攻": return "高位擋拆讀換防。對手人盯人時錯位↑，對手區域時較吃虧。"
		"半場傳導": return "傳導找空檔。對手沉退時外線空檔↑，對手壓迫時球容易被切斷。"
		"牛角進攻": return "雙高位落位，空切與外線並用。"
		"人盯人": return "一人看一人。對手持球火力時較吃虧。"
		"區域聯防": return "收縮禁區。內線↓，底角三分空檔↑。"
		"全場壓迫": return "過半場前上壓，逼失誤打轉換。"
		"沉退聯防": return "內縮護禁區。禁區單打↓，外線空檔↑。"
		_: return "策略會影響每節比分與三分。"

func quarter_event(index: int, home_points: int, away_points: int) -> String:
	var lead := "我方拉開比分" if home_points > away_points else "對手掌握節奏"
	var star := str(team_players[0].get("name", "先發")) if not team_players.is_empty() else "先發"
	var wing := str(team_players[1].get("name", "側翼")) if team_players.size() > 1 else "側翼"
	var events := [
		"開局攻防快速，%s。%s 開始掌控球權。" % [lead, star],
		"第二節輪轉穩定，%s 在外線找到手感。" % wing,
		"第三節防守強度提升，%s。" % lead,
		"末節進入關鍵回合，%s 挺身完成收官。" % star
	]
	return events[clampi(index, 0, events.size() - 1)] + " 本節 %d - %d。" % [home_points, away_points]

func team_score(club_title: String, score: String, accent: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(260, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -4)
	box.add_child(kicker_label(club_title, 13, TEXT))
	box.add_child(number_label(score, 36 if is_handheld() else 56, accent))
	return box

func quarter_row(period: String, home_value: String, away_value: String, revealed: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(Color("142334"), GREEN if revealed else Color("2c4359"), 10, 1))
	var row := HBoxContainer.new()
	panel.add_child(padded(row, 7))
	row.add_child(score_chip(period, 14, CYAN if revealed else MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(score_chip(home_value, 18, ORANGE if revealed else MUTED))
	row.add_child(score_chip("-", 14, MUTED))
	row.add_child(score_chip(away_value, 18, CYAN if revealed else MUTED))
	return panel

func score_chip(text_value: String, font_px: int, color: Color) -> Label:
	var node := number_label(text_value, font_px, color)
	node.custom_minimum_size = Vector2(28, ceil(font_px * 1.4))
	return node

func match_summary(title: String, body: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("111d2aed"), accent.darkened(0.25), 14, 1))
	var box := VBoxContainer.new()
	panel.add_child(padded(box, 12))
	box.add_child(label(title, 14, accent, true))
	box.add_child(label(body, 17, TEXT, true))
	return panel

func match_info(title: String, body: String, footer: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("111d2aed"), accent.darkened(0.25), 16, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(padded(box, 10 if is_handheld() else 14))
	box.add_child(label(title, 15, accent.lightened(0.14), true))
	box.add_child(wrap_label(body, 15, TEXT))
	if not footer.is_empty():
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		box.add_child(label(footer, 11, MUTED))
	return panel

func dashboard_panel(title: String, body: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(Color("111d2aed"), accent.darkened(0.22), 16, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(padded(box, 14))
	box.add_child(label(title, 15, accent, true))
	box.add_child(label(body, 15, TEXT, true))
	return panel

func option_block(title: String, description: String, button_text: String, action: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(Color("172536e8"), Color("385571"), 16, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	panel.add_child(padded(row, 11))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(label(title, 15, TEXT, true))
	var description_label := label(description, 11, MUTED)
	description_label.custom_minimum_size = Vector2(0, 32)
	description_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	words.add_child(description_label)
	row.add_child(words)
	row.add_child(action_button(button_text, Color("254e6b"), action, Vector2(108, 42)))
	return panel

func result_recap_grid() -> Control:
	var phone := compact_phone()
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", 6 if phone else 8)
	var home_title := "場地"
	var home_body := last_match_venue_line()
	var home_accent := GREEN if last_home_points > 0 else MUTED
	var q_body := "尚無紀錄"
	if quarter_scores.size() >= 2 and quarter_scores[0] is Array and quarter_scores[1] is Array and quarter_scores[0].size() >= 4 and quarter_scores[1].size() >= 4:
		q_body = period_score_summary()
	row.add_child(result_recap_tile("本場", "先發＋替補", GOLD, func(): show_box_score_sheet(), true))
	row.add_child(result_recap_tile(home_title, home_body, home_accent))
	row.add_child(result_recap_tile("各節比分", q_body, CYAN))
	row.add_child(result_recap_tile("數據王", kings_summary_line(), GOLD))
	return row

func result_recap_row(cells: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", 6 if compact_phone() else 8)
	for cell in cells:
		if cell is Control:
			row.add_child(cell)
	return row

func result_recap_tile(title: String, body: String, accent: Color, action := Callable(), gold_hit := false) -> Control:
	var phone := compact_phone()
	var host: Control
	if action.is_valid():
		var hit := Button.new()
		hit.text = ""
		hit.clip_contents = true
		hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.custom_minimum_size = Vector2(0, 36 if phone else 40)
		if gold_hit:
			hit.add_theme_stylebox_override("normal", gold_metal_style())
			hit.add_theme_stylebox_override("hover", gold_metal_style(false, true))
			hit.add_theme_stylebox_override("pressed", gold_metal_style(true, false))
			hit.add_theme_stylebox_override("focus", gold_metal_style())
		else:
			var rest := panel_style(accent.darkened(0.75), accent.darkened(0.22), 13, 1)
			hit.add_theme_stylebox_override("normal", rest)
			hit.add_theme_stylebox_override("hover", panel_style(accent.darkened(0.68), accent, 13, 1))
			hit.add_theme_stylebox_override("pressed", panel_style(accent.darkened(0.80), accent.darkened(0.10), 13, 1))
			hit.add_theme_stylebox_override("focus", rest)
		hit.pressed.connect(func():
			play_sfx("tap")
			action.call()
		)
		bind_press_juice(hit, hit)
		host = hit
	else:
		var panel := PanelContainer.new()
		panel.clip_contents = true
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(0, 36 if phone else 40)
		panel.add_theme_stylebox_override("panel", panel_style(accent.darkened(0.75), accent.darkened(0.22), 13, 1))
		host = panel
	var inner := HBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 6)
	var inset := padded(inner, 6 if phone else 8)
	if host is Button:
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(inset)
	var mark := plain_label("◆", 12 if phone else 13, Color("fff6d8") if gold_hit else accent, true)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(mark)
	var title_col := Color("fff6d8") if gold_hit else TEXT
	var body_col := Color("ffe9a8") if gold_hit else MUTED
	var head := plain_label(title, 12 if phone else 13, title_col, true)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(head)
	var copy := plain_label(body, 10 if phone else 11, body_col, false)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.clip_text = true
	copy.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(copy)
	return host

func callout(title: String, body: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.clip_contents = false
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", panel_style(accent.darkened(0.75), accent.darkened(0.22), 13, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(padded(row, 10))
	row.add_child(plain_label("◆", 17, accent, true))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(wrap_label(title, 14, TEXT, true))
	words.add_child(wrap_label(body, 12, MUTED))
	row.add_child(words)
	return panel

func roster_count_pill(title: String, value: String, accent: Color, on_press := Callable()) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 28)
	panel.add_theme_stylebox_override("panel", panel_style(Color("132536e8"), accent.darkened(0.20), 8, 1))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 6)
	panel.add_child(padded(line, 4))
	line.add_child(plain_label(title, 10, MUTED, true))
	line.add_child(plain_label(value, 13, accent, true))
	if on_press.is_valid():
		var hit := Button.new()
		hit.text = ""
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.flat = true
		hit.tooltip_text = "打開%s" % title
		hit.add_theme_stylebox_override("normal", invisible_style())
		hit.add_theme_stylebox_override("hover", invisible_style())
		hit.add_theme_stylebox_override("pressed", invisible_style())
		hit.add_theme_stylebox_override("focus", invisible_style())
		hit.pressed.connect(func():
			play_sfx("tap")
			on_press.call()
		)
		panel.add_child(hit)
	return panel

func stat_chip(title: String, value: String, accent: Color) -> PanelContainer:
	return roster_count_pill(title, value, accent)

func gold_metal_style(pressed := false, hover := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if pressed:
		style.bg_color = Color("8a6410")
	elif hover:
		style.bg_color = Color("d4a017")
	else:
		style.bg_color = Color("b8891a")
	style.border_color = Color("f3de8a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(0.95, 0.78, 0.28, 0.48)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style

func gold_select_style() -> StyleBoxFlat:
	var style := gold_metal_style()
	style.set_corner_radius_all(16)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.shadow_size = 10
	return style

func gold_action_button(text_value: String, action: Callable, minimum := Vector2(0, 40)) -> Button:
	var button := Button.new()
	button.set_meta("button_role", "primary")
	button.text = text_value
	button.clip_contents = true
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size = touch_minimum(Vector2(minimum.x, maxf(minimum.y, 40.0)))
	if minimum.x <= 0:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 80 if is_handheld() else 64
	button.add_theme_font_override("font", font_display())
	button.add_theme_font_size_override("font_size", 20 if is_handheld() else 17)
	button.add_theme_color_override("font_color", Color("fff6d8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("fff4cc"))
	punch_text(button, 20 if is_handheld() else 17)
	button.add_theme_stylebox_override("normal", gold_metal_style())
	button.add_theme_stylebox_override("hover", gold_metal_style(false, true))
	button.add_theme_stylebox_override("pressed", gold_metal_style(true, false))
	button.add_theme_stylebox_override("disabled", panel_style(Color("28313b"), Color("3c4854"), 12, 1))
	button.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	bind_press_juice(button, button)
	return button

func play_start_button(action: Callable, minimum := Vector2(168, 44)) -> Button:
	return gold_action_button("開打", action, Vector2(maxf(minimum.x, 160.0 if is_handheld() else 112.0), minimum.y))

func action_button(text_value: String, color: Color, action: Callable, minimum := Vector2(0, 44)) -> Button:
	var button := Button.new()
	button.text = text_value
	button.clip_contents = true
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size = touch_minimum(Vector2(minimum.x, maxf(minimum.y, 44.0)))
	if minimum.x <= 0:
		# Auto-width buttons in horizontal rows must share the available width.
		# clip_text removes their intrinsic text width, otherwise they collapse to a line.
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 80 if is_handheld() else 64
	button.add_theme_font_override("font", font_display())
	button.add_theme_font_size_override("font_size", 20 if is_handheld() else 16)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	punch_text(button, 20 if is_handheld() else 16)
	button.add_theme_stylebox_override("normal", panel_style(color, color.lightened(0.15), 13, 1))
	button.add_theme_stylebox_override("hover", panel_style(color.lightened(0.10), color.lightened(0.30), 13, 2))
	button.add_theme_stylebox_override("pressed", panel_style(color.darkened(0.12), Color.WHITE, 13, 1))
	button.add_theme_stylebox_override("disabled", panel_style(Color("28313b"), Color("3c4854"), 13, 1))
	button.pressed.connect(func():
		play_sfx("tap")
		action.call()
	)
	bind_press_juice(button, button)
	return button

func text_field(placeholder: String, initial := "") -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.text = initial
	field.custom_minimum_size = touch_minimum(Vector2(0, 48))
	field.add_theme_font_override("font", FONT_BOLD)
	field.add_theme_font_size_override("font_size", 22 if is_handheld() else 15)
	field.add_theme_color_override("font_color", TEXT)
	field.add_theme_color_override("font_placeholder_color", MUTED)
	punch_text(field, 15)
	field.add_theme_stylebox_override("normal", panel_style(Color("0b1420"), Color("334b61"), 11, 1))
	field.add_theme_stylebox_override("focus", panel_style(Color("0d1825"), ORANGE, 11, 2))
	return field

func section_title(text_value: String) -> Label:
	return kicker_label(text_value, 12, MUTED, HORIZONTAL_ALIGNMENT_LEFT)

func font_display() -> Font:
	return FONT_BOLD

func font_number() -> Font:
	if _font_number == null:
		_font_number = FontVariation.new()
		_font_number.base_font = FONT_NUMBER_FILE
		_font_number.spacing_glyph = -1
		_font_number.fallbacks = [FONT_BOLD, FONT_REGULAR]
	return _font_number

func font_kicker() -> Font:
	if _font_kicker == null:
		_font_kicker = FontVariation.new()
		_font_kicker.base_font = FONT_KICKER_FILE
		_font_kicker.spacing_glyph = 1
		_font_kicker.fallbacks = [FONT_BOLD, FONT_REGULAR]
	return _font_kicker

func typeface(bold: bool, font_px: int) -> Font:
	if not bold:
		return FONT_REGULAR
	if font_px >= 15:
		return font_display()
	return FONT_BOLD

func punch_text(node: Control, font_px: int) -> Control:
	if is_handheld() and font_px <= 24:
		node.add_theme_constant_override("outline_size", 1)
		node.add_theme_constant_override("font_outline_size", 1)
		node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
		node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		node.add_theme_constant_override("shadow_offset_x", 0)
		node.add_theme_constant_override("shadow_offset_y", 0)
		node.add_theme_constant_override("shadow_outline_size", 0)
		return node
	var ink := TEXT
	if node.has_theme_color_override("font_color"):
		ink = node.get_theme_color("font_color")
	var dark := ink.r * 0.299 + ink.g * 0.587 + ink.b * 0.114 < 0.45
	if dark:
		node.add_theme_constant_override("outline_size", 0)
		node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		if node is Label:
			node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			node.add_theme_constant_override("shadow_offset_x", 0)
			node.add_theme_constant_override("shadow_offset_y", 0)
			node.add_theme_constant_override("shadow_outline_size", 0)
		elif node is Button or node is LineEdit:
			node.add_theme_constant_override("font_outline_size", 0)
			node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		return node
	var outline := maxi(4, int(round(float(font_px) * 0.28)))
	node.add_theme_constant_override("outline_size", outline)
	node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	if node is Label:
		node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		node.add_theme_constant_override("shadow_offset_x", 2)
		node.add_theme_constant_override("shadow_offset_y", 2)
		node.add_theme_constant_override("shadow_outline_size", maxi(3, int(round(float(font_px) * 0.22))))
	elif node is Button or node is LineEdit:
		node.add_theme_constant_override("font_outline_size", outline)
		node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	return node

func polish_title(node: Label) -> Label:
	node.add_theme_font_override("font", font_display())
	punch_text(node, node.get_theme_font_size("font_size") if node.has_theme_font_size_override("font_size") else 18)
	return node

func kicker_label(text_value: String, font_px: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	if is_handheld():
		font_px = maxi(font_px, 16)
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_override("font", FONT_BOLD)
	node.add_theme_font_size_override("font_size", font_px)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = alignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	punch_text(node, font_px)
	return node

func number_label(text_value: String, font_px: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	if is_handheld():
		font_px = maxi(font_px, 16)
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_override("font", font_number())
	node.add_theme_font_size_override("font_size", font_px)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = alignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	punch_text(node, font_px)
	return node

func ovr_stack(ovr: int, accent: Color, compact := false) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -3)
	box.add_child(kicker_label("OVR", 7 if compact else 9, Color(accent.r, accent.g, accent.b, 0.78)))
	box.add_child(number_label(str(ovr), 18 if compact else 26, accent))
	return box

func plain_label(text_value: String, font_px: int, color := TEXT, bold := false, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	if is_handheld():
		font_px = maxi(font_px, 16)
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_override("font", typeface(bold, font_px))
	node.add_theme_font_size_override("font_size", font_px)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = alignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.clip_text = false
	node.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	punch_text(node, font_px)
	return node

func label(text_value: String, font_px: int, color := TEXT, bold := false, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	if is_handheld():
		font_px = maxi(font_px, 16)
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_override("font", typeface(bold, font_px))
	node.add_theme_font_size_override("font_size", font_px)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = alignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	punch_text(node, font_px)
	return node

func wrap_label(text_value: String, font_px: int, color := TEXT, bold := false, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	if is_handheld():
		font_px = maxi(font_px, 16)
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_override("font", typeface(bold, font_px))
	node.add_theme_font_size_override("font_size", font_px)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = alignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	punch_text(node, font_px)
	return node

func pill(text_value: String, color: Color, background: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(background, color.darkened(0.22), 11, 1))
	var text_node := label(text_value, 11, color, true, HORIZONTAL_ALIGNMENT_CENTER)
	text_node.custom_minimum_size = Vector2(88, 28)
	panel.add_child(text_node)
	return panel

func separator() -> HSeparator:
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 8)
	line.add_theme_stylebox_override("separator", panel_style(Color("2d4559"), Color("2d4559"), 0, 0))
	return line

func h_chip_scroll(row: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = touch_minimum(Vector2(0, 34))
	sc.scroll_deadzone = 12 if is_handheld() else 0
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.clip_contents = true
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sc.add_child(row)
	return sc

func padded(control: Control, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = control.size_flags_horizontal
	margin.size_flags_vertical = control.size_flags_vertical
	margin.size_flags_stretch_ratio = control.size_flags_stretch_ratio
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	margin.add_child(control)
	return margin

func panel_style(background: Color, border: Color, radius: int, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 1)
	style.anti_aliasing = false
	return style

func invisible_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.set_border_width_all(0)
	style.set_content_margin_all(0)
	style.shadow_size = 0
	return style

func ensure_sfx() -> void:
	if is_instance_valid(sfx_player):
		return
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SfxPlayer"
	sfx_player.bus = "Master"
	add_child(sfx_player)

func ensure_bgm() -> void:
	if not is_instance_valid(bgm_player):
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = "BgmPlayer"
		bgm_player.volume_db = -11.0
		bgm_player.bus = "Master"
		bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		bgm_player.stream = load_bgm_stream()
		bgm_player.finished.connect(_on_bgm_finished)
		add_child(bgm_player)
	elif bgm_player.stream == null:
		bgm_player.stream = load_bgm_stream()
	apply_audio_settings()

func _kick_bgm() -> void:
	ensure_bgm()
	if bgm_on and is_instance_valid(bgm_player) and bgm_player.stream != null and not bgm_player.playing:
		bgm_player.play()

func _on_bgm_finished() -> void:
	if bgm_on and is_instance_valid(bgm_player) and bgm_player.stream != null:
		bgm_player.play()

func load_audio_settings() -> void:
	if not FileAccess.file_exists(AUDIO_SETTINGS_PATH):
		bgm_on = true
		sfx_on = true
		return
	var file := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	sfx_on = bool(data.get("sfx_on", true))
	bgm_on = bool(data.get("bgm_on", true))
	bgm_volume = clampf(float(data.get("bgm_volume", 0.28)), 0.0, 1.0)

func save_audio_settings() -> void:
	var file := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"sfx_on": sfx_on, "bgm_on": bgm_on, "bgm_volume": bgm_volume}))

func apply_audio_settings() -> void:
	if not is_instance_valid(bgm_player):
		return
	if bgm_on:
		bgm_player.volume_db = -80.0 if bgm_volume <= 0.001 else linear_to_db(bgm_volume)
		if bgm_player.stream == null:
			bgm_player.stream = load_bgm_stream()
		if bgm_player.stream != null and not bgm_player.playing:
			bgm_player.play()
	elif bgm_player.playing:
		bgm_player.stop()

func load_wav_stream(path: String) -> AudioStreamWAV:
	var disk := path
	if path.begins_with("res://"):
		if FileAccess.file_exists(path):
			disk = path
		else:
			disk = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(disk):
		return null
	var file := FileAccess.open(disk, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() < 12:
		return null
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var channels := 0
	var rate := 0
	var bits := 0
	var data := PackedByteArray()
	var pos := 12
	while pos + 8 <= bytes.size():
		var cid := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var csz := int(bytes.decode_u32(pos + 4))
		var payload := pos + 8
		if payload > bytes.size():
			break
		var take := mini(csz, bytes.size() - payload)
		if cid == "fmt " and take >= 16:
			channels = bytes.decode_u16(payload + 2)
			rate = int(bytes.decode_u32(payload + 4))
			bits = bytes.decode_u16(payload + 14)
		elif cid == "data":
			data = bytes.slice(payload, payload + take)
			break
		pos = payload + csz
		if csz % 2 == 1:
			pos += 1
	if bits != 16 or channels < 1 or data.is_empty():
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = channels > 1
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func load_mp3_file(disk: String) -> AudioStream:
	if disk.is_empty() or not FileAccess.file_exists(disk):
		return null
	var file := FileAccess.open(disk, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() < 64:
		return null
	# 素材檔其實是 AAC/M4A 卻叫 .mp3，minimp3 解不開。
	if bytes.size() >= 12 and bytes.slice(4, 8).get_string_from_ascii() == "ftyp":
		return null
	if bytes.size() >= 3 and bytes[0] == 0x00 and bytes[1] == 0x00 and bytes[2] == 0x00:
		return null
	var stream := AudioStreamMP3.new()
	stream.data = bytes
	stream.loop = true
	if stream.get_length() <= 0.1:
		return null
	return stream

func load_bgm_stream() -> AudioStream:
	var wav := load_wav_stream("res://assets/audio/hiphop_lobby.wav")
	if wav != null:
		return wav
	var imported: Variant = load("res://assets/audio/hiphop_lobby.wav")
	if imported is AudioStreamWAV:
		return imported
	imported = load("res://assets/audio/hiphop_lobby.mp3")
	if imported is AudioStreamMP3:
		(imported as AudioStreamMP3).loop = true
		return imported
	var root := ProjectSettings.globalize_path("res://")
	var runtime := load_mp3_file(root.path_join("assets/audio/hiphop_lobby.mp3"))
	if runtime != null:
		return runtime
	return bgm_stream()

func play_sfx(kind: String) -> void:
	if not sfx_on:
		return
	ensure_sfx()
	match kind:
		"tap":
			sfx_player.stream = tone_stream(880.0, 0.05, 0.11)
		"whistle":
			sfx_player.stream = tone_stream(1760.0, 0.18, 0.13)
		"score":
			sfx_player.stream = tone_stream(620.0, 0.12, 0.15)
		"skill":
			sfx_player.stream = tone_stream(1040.0, 0.20, 0.15)
		"buzzer":
			sfx_player.stream = tone_stream(180.0, 0.28, 0.17)
		"pack":
			sfx_player.stream = tone_stream(1320.0, 0.22, 0.16)
		"new_card":
			sfx_player.stream = tone_stream(1480.0, 0.28, 0.18)
		"tier_up":
			sfx_player.stream = tone_stream(1180.0, 0.34, 0.20)
		"purchase":
			sfx_player.stream = tone_stream(1560.0, 0.30, 0.20)
		_:
			return
	sfx_player.play()

func show_purchase_success(title: String, detail := "") -> void:
	close_guide_modal()
	play_sfx("purchase")
	var veil := ColorRect.new()
	veil.name = "DuplicateCardNotice" if detail.contains("重複卡") else "PurchaseSuccessModal"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color("02060bb8")
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 95
	guide_modal = veil
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(center)
	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(300 if compact_phone() else 390, 0)
	dialog.add_theme_stylebox_override("panel", panel_style(Color("0b1420fa"), GOLD, 18, 2))
	center.add_child(dialog)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	dialog.add_child(padded(box, 20 if compact_phone() else 26))
	box.add_child(plain_label("✓", 32 if compact_phone() else 42, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(label("購買成功", 21 if compact_phone() else 26, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(label(title, 16 if compact_phone() else 19, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	if not detail.is_empty():
		box.add_child(wrap_label(detail, 12 if compact_phone() else 14, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(action_button("確定", ORANGE, func(): close_guide_modal(), Vector2(150, 44 if compact_phone() else 48)))
	veil.modulate.a = 0.0
	veil.create_tween().tween_property(veil, "modulate:a", 1.0, 0.16)

func queue_purchase_success(title: String, detail := "") -> void:
	# Callers rebuild their destination screen before this helper, so the modal
	# can be attached immediately and is also observable in the same UI frame.
	show_purchase_success(title, detail)

func bgm_stream() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 6.0
	var count := int(float(rate) * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var wave := sin(t * TAU * 110.0) * 0.18 + sin(t * TAU * 164.8) * 0.10 + sin(t * TAU * 220.0) * 0.06
		wave *= 0.72 + 0.28 * sin(t * TAU * 0.25)
		var sample := int(clampf(wave * 18000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream

func tone_stream(freq: float, seconds: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(8, int(float(rate) * seconds))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var env := 1.0 - t / maxf(seconds, 0.01)
		var sample := int(clampf(sin(t * TAU * freq) * volume * env * 32767.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

func card_frame_for(key: String) -> Texture2D:
	var file := "gold"
	match key:
		"red", "blue", "green", "purple", "cyan", "gold", "diamond":
			file = key
	var raw := load_png_tex("res://assets/cards/card_%s.png" % file)
	return slim_card_frame(raw, file)

func card_court_for(player: Dictionary) -> Texture2D:
	var tier := player_tier_key(player)
	var path := "res://assets/ui/arena_bg.png"
	match tier:
		"gold":
			path = "res://assets/art/arena_playoff.png"
		"diamond":
			path = "res://assets/art/arenas/cyberpunk_arena_base.png"
		_:
			# Stable per-player rotation gives the collection several court styles
			# without changing when the card moves between roster and vault.
			var courts := [
				"res://assets/ui/arena_bg.png",
				"res://assets/ui/half_court.png",
				"res://assets/art/arena_night.png",
				"res://assets/art/arenas/cyberpunk_arena_base.png",
			]
			var identity := player_identity_key(player)
			if identity.is_empty():
				identity = str(player.get("name", player.get("id", "player")))
			path = courts[absi(identity.hash()) % courts.size()]
	return load_png_tex(path)

func card_court_tint(player: Dictionary) -> Color:
	match player_tier_key(player):
		"cyan": return Color("87929ca8")
		"green": return Color("82cba7b8")
		"blue": return Color("88afe0c4")
		"red": return Color("df8b91c8")
		"purple": return Color("bd91e8d0")
		"gold": return Color("ffe284dc")
		"diamond": return Color("d8f5ffe8")
		_: return Color("ffffffc0")

func slim_card_frame(tex: Texture2D, key: String) -> Texture2D:
	if tex == null:
		return null
	var cache_key := "frame#clean3#%s" % key
	if _tex_cache.has(cache_key) and _tex_cache[cache_key] is Texture2D:
		return _tex_cache[cache_key]
	var img := tex.get_image()
	if img == null:
		return tex
	img.convert(Image.FORMAT_RGBA8)
	punch_card_frame_hole(img)
	var cleaned := ImageTexture.create_from_image(img)
	_tex_cache[cache_key] = cleaned
	return cleaned

func punch_card_frame_hole(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w < 32 or h < 32:
		return
	var x0 := int(round(float(w) * 0.16))
	var x1 := int(round(float(w) * 0.84))
	var y0 := int(round(float(h) * 0.18))
	var y1 := int(round(float(h) * 0.78))
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, Color(0, 0, 0, 0))

func card_frame_tint(_key: String) -> Color:
	return Color.WHITE

func tier_color(key: String) -> Color:
	match key:
		"red": return Color("e85a72")
		"blue": return Color("4a8ae8")
		"purple": return Color("b56ef0")
		"diamond": return Color("d6f4ff")
		"green": return Color("3ecf9a")
		"cyan": return Color("3ae8d4")
		_: return Color("e4bc4a")

func flash_notice(message: String) -> void:
	if is_instance_valid(notice_node):
		notice_node.queue_free()
	var pad := screen_safe_pad()
	var notice := PanelContainer.new()
	notice_node = notice
	notice.z_index = 80
	notice.mouse_filter = Control.MOUSE_FILTER_STOP
	notice.set_anchors_preset(Control.PRESET_TOP_WIDE)
	notice.anchor_left = 0.0
	notice.anchor_right = 1.0
	notice.offset_left = float(pad.x)
	notice.offset_right = -float(pad.z)
	notice.offset_top = float(pad.y) + 8.0
	notice.offset_bottom = float(pad.y) + 64.0
	notice.add_theme_stylebox_override("panel", panel_style(Color("18283af7"), ORANGE, 14, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	notice.add_child(padded(row, 6))
	var text_node := wrap_label(message, 13, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	text_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(text_node)
	var close := action_button("×", Color("33475a"), func():
		if is_instance_valid(notice):
			notice.queue_free()
	, Vector2(36, 36))
	close.add_theme_font_size_override("font_size", 20)
	close.tooltip_text = "關閉提示"
	row.add_child(close)
	add_child(notice)
	notice.modulate.a = 0.0
	var tween := notice.create_tween()
	tween.tween_property(notice, "modulate:a", 1.0, 0.16)
	tween.tween_interval(1.6)
	tween.tween_property(notice, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		if is_instance_valid(notice):
			notice.queue_free()
	)

func roll_one_period(q: int, rng: RandomNumberGenerator) -> void:
	var profiles := quarter_match_profiles(q)
	var triggered: Array = current_skill_modifiers.get("triggered", [])
	var names: Array = current_skill_modifiers.get("names", [])
	var cutins: Dictionary = current_skill_modifiers.get("cutins", {})
	for player in active_match_players(q):
		var event := trigger_skill_event(player, mini(q + 1, 4), 0.0)
		if event.is_empty():
			continue
		profiles[0].offense += float(event.get("offense", 0)) * 0.12
		profiles[0].defense += float(event.get("defense", 0)) * 0.12
		if q >= 3:
			profiles[0].offense += float(event.get("q4", 0)) * 0.12
		triggered.append("%s  %s 觸發 %s" % [period_label(q), event.player, event.name])
		names.append(str(event.player))
		if not cutins.has(str(q + 1)):
			cutins[str(q + 1)] = event.duplicate(true)
			cutins[str(q + 1)]["player_data"] = player.duplicate(true)
	for player in profiles[1].get("active", []):
		var event := skill_event_for(player, mini(q + 1, 4), 0.0, str(profiles[1].get("attack", "半場傳導")), str(profiles[1].get("cover", "人盯人")))
		if event.is_empty():
			continue
		profiles[1].offense += float(event.get("offense", 0)) * 0.12
		profiles[1].defense += float(event.get("defense", 0)) * 0.12
		if q >= 3:
			profiles[1].offense += float(event.get("q4", 0)) * 0.12
	var result := MatchSimulator.period(profiles[0], profiles[1], rng, q >= 4)
	quarter_scores[0].append(int(result.a))
	quarter_scores[1].append(int(result.b))
	var threes: Array = current_skill_modifiers.get("period_threes", [])
	threes.append([int(result.threes_a), int(result.threes_b)])
	current_skill_modifiers["period_threes"] = threes
	match_threes = [0, 0]
	for period in threes:
		if period is Array and period.size() == 2:
			match_threes[0] += int(period[0])
			match_threes[1] += int(period[1])
	var story := human_quarter_story(q, oncourt_player(q), int(result.a), int(result.b)) if q < 4 else "%s 延長賽 %d－%d" % [period_label(q), int(result.a), int(result.b)]
	quarter_stories.append(story)
	match_event_log.append(story)
	current_skill_modifiers["triggered"] = triggered
	current_skill_modifiers["names"] = names
	current_skill_modifiers["cutins"] = cutins

func period_score_summary() -> String:
	var lines: Array[String] = []
	if quarter_scores.size() == 2:
		for q in mini(quarter_scores[0].size(), quarter_scores[1].size()):
			lines.append("%s  %d－%d" % [period_label(q), int(quarter_scores[0][q]), int(quarter_scores[1][q])])
	return "\n".join(lines)

func last_match_venue_line() -> String:
	var venue := str(current_skill_modifiers.get("venue", "主場" if last_home_points > 0 else "客場"))
	return venue + (" · 戰力 +2" if venue == "主場" else (" · 對手戰力 +2" if venue == "客場" else " · 無主場加成"))
