## 真实关卡的测试宿主：仅隔离账户写入，清场、死亡、HUD 和场景跳转沿用生产实现。
extends FortressLevelController


## 不调用 CurrencyManager.settle_run，避免自动化测试解锁用户账户或清空钱包。
func _on_run_finished(won: bool) -> void:
    if won:
        RunStats.finish(true, total_score, GameManager.get_run_snapshot(), CurrencyManager.get_snapshot())
        controlled_hud.show_run_victory(total_score)


## 同样只隔离战败账户结算；保留实际失败状态与完整死亡演出。
func _on_player_died() -> void:
    GameManager.fail_run(self)
    RunStats.finish(false, total_score, GameManager.get_run_snapshot(), CurrencyManager.get_snapshot())
    controlled_hud.show_defeat(total_score)
