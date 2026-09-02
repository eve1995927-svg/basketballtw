#!/usr/bin/env python3
"""Static guard for the Supabase economy migration.

This does not replace running the migration in Supabase. It catches accidental
regressions where client supplied reward values or deprecated auth.role() checks
are reintroduced before deployment.
"""
from pathlib import Path
import re, sys

p = Path(__file__).resolve().parents[1] / "supabase" / "security_economy.sql"
s = p.read_text(encoding="utf-8")
client = p.parent.parent / "scripts" / "main.gd"
client_source = client.read_text(encoding="utf-8")
checks = {
    "no deprecated auth.role": "auth.role()" not in s,
    "jwt service role check": "auth.jwt()->>'role'" in s,
    "canonical win budget": "reward_budget := 20" in s,
    "canonical loss budget": "reward_budget := 10" in s,
    "canonical win gold range": "reward_gold := 5 + mod" in s,
    "canonical win scout range": "reward_scout := 1 + mod" in s,
    "canonical training reward": "reward_training := 1" in s,
    "settlement stores derived rewards": "values(uid,p_match_id,p_won,p_league,reward_budget,reward_gold,reward_scout,reward_training)" in s,
    "training fixed cost": "p_delta_budget <> -20" in s and "p_delta_training <> -1" in s,
    "scout refresh fixed cost": "p_delta_gold <> -20" in s and "INVALID_SCOUT_REFRESH_COST" in s,
    "authenticated settle grant": bool(re.search(r"grant execute on function public\.godot_match_settle[\s\S]*?to authenticated", s)),
    "server owned scout purchase": "godot_scout_purchase" in s and "PLAYER_NOT_IN_CATALOG" in s,
    "server owned signing": "godot_sign_player" in s and "sign_player" in s and "PLAYER_NOT_IN_CATALOG" in s,
    "server owned trade fee": "godot_trade_fee" in s and "trade_fee" in s and "PLAYER_NOT_IN_CATALOG" in s,
    "authenticated market grants": bool(re.search(r"grant execute on function public\.godot_sign_player[\s\S]*?to authenticated", s)) and bool(re.search(r"grant execute on function public\.godot_trade_fee[\s\S]*?to authenticated", s)),
    "release config table": "godot_release_config" in s,
    "client release gate": all(token in client_source for token in ["request_release_gate", "version_at_least", "release_gate_blocked", "finish_auth_enter()"]),
}
failed = [name for name, ok in checks.items() if not ok]
print("SECURITY_ECONOMY_AUDIT " + " ".join(f"{name}={'ok' if ok else 'FAIL'}" for name, ok in checks.items()))
if failed:
    print("FAILED: " + ", ".join(failed))
    sys.exit(1)
