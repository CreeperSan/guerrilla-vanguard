class_name Definition

# 阵营
enum Faction {
    Player, # 玩家阵营
    Enemy,  # 敌对阵营
    Friend, # 盟友
}

## 子弹效果类型。
enum BulletType {
    Bullet,     ## 命中时直接造成伤害。
    Explosion,  ## 命中或到达射程后生成爆炸。
    Burning,    ## 命中或到达射程后生成燃烧区域。
}
