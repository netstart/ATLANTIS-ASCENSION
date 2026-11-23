"""Textos das naves premium (data/ships.json "premium", scripts/core/iap.gd, a seção "Naves premium" da Loja e a
coleção de naves): nomes, a vitrine e o aviso honesto de que só o visual é exclusivo (o kit é o de uma nave do
hangar, sem força extra).
Ordem: pt_BR, en, es, de, fr, ru, id, ja, ko, zh_TW, zh_CN.
"""

STRINGS = {
    "ship.hippocampus": ["Hipocampo", "Hippocampus", "Hipocampo", "Hippokamp", "Hippocampe", "Гиппокамп",
                         "Hippocampus", "ヒッポカムポス", "히포캄포스", "海馬神駒", "海马神驹"],
    "ship.nereid": ["Nereida", "Nereid", "Nereida", "Nereide", "Néréide", "Нереида", "Nereid", "ネレイス", "네레이드",
                    "涅瑞伊得", "涅瑞伊得"],
    "ship.amphitrite": ["Anfitrite", "Amphitrite", "Anfitrite", "Amphitrite", "Amphitrite", "Амфитрита",
                        "Amphitrite", "アムピトリーテー", "암피트리테", "安菲特里忒", "安菲特里忒"],
    "store.premium_section": ["Naves premium", "Premium ships", "Naves premium", "Premium-Schiffe",
                              "Vaisseaux premium", "Премиум-корабли", "Kapal premium", "プレミアム機",
                              "프리미엄 기체", "高級戰機", "高级战机"],
    "store.premium_badge": ["Premium", "Premium", "Premium", "Premium", "Premium", "Премиум", "Premium", "プレミアム",
                            "프리미엄", "高級", "高级"],
    "store.premium_fleet": ["Frota premium", "Premium fleet", "Flota premium", "Premium-Flotte", "Flotte premium",
                            "Премиум-флот", "Armada premium", "プレミアム艦隊", "프리미엄 함대", "高級艦隊", "高级舰队"],
    "store.premium_fleet_desc": [
        "As três naves premium juntas, por menos.", "All three premium ships together, for less.",
        "Las tres naves premium juntas, por menos.", "Alle drei Premium-Schiffe zusammen, günstiger.",
        "Les trois vaisseaux premium ensemble, pour moins cher.", "Все три премиум-корабля вместе и дешевле.",
        "Ketiga kapal premium sekaligus, lebih hemat.", "プレミアム機3機をまとめてお得に。",
        "프리미엄 기체 세 대를 한 번에, 더 저렴하게.", "三架高級戰機一次入手，更划算。", "三架高级战机一次入手，更划算。"],
    "store.premium_save": [
        "Economize %d%% em vez de comprar separadas", "Save %d%% versus buying them separately",
        "Ahorra un %d%% frente a comprarlas por separado", "Spare %d%% gegenüber dem Einzelkauf",
        "Économisez %d%% par rapport à l'achat séparé", "Экономия %d%% по сравнению с покупкой по отдельности",
        "Hemat %d%% dibanding beli terpisah", "別々に買うより%d%%お得", "따로 사는 것보다 %d%% 절약",
        "比分開購買省 %d%%", "比分开购买省 %d%%"],
    "store.premium_kit": [
        "Joga como a %s: mesmo casco, arma, especial e poderes.", "Plays like the %s: same hull, weapon, special and powers.",
        "Juega como la %s: mismo casco, arma, especial y poderes.", "Spielt wie die %s: gleiche Hülle, Waffe, Spezial und Kräfte.",
        "Joue comme le %s : même coque, arme, spécial et pouvoirs.", "Играет как %s: тот же корпус, оружие, спецприём и силы.",
        "Bermain seperti %s: lambung, senjata, spesial, dan kekuatan sama.", "%sと同じ性能：機体、武器、必殺、パワーも同じ。",
        "%s와 같은 성능: 선체, 무기, 특수기, 능력 동일.", "性能同%s：機體、武器、特技與能力相同。", "性能同%s：机体、武器、特技与能力相同。"],
    "store.premium_note": [
        "Visual exclusivo, não é mais forte.", "Exclusive look, not stronger.", "Aspecto exclusivo, no es más fuerte.",
        "Exklusiver Look, nicht stärker.", "Look exclusif, pas plus fort.", "Эксклюзивный облик, не сильнее.",
        "Tampilan eksklusif, tidak lebih kuat.", "限定の見た目。強さは同じです。", "한정 외형, 더 강하지 않습니다.",
        "獨家外觀，不會更強。", "独家外观，不会更强。"],
    "store.premium_owned": ["Na sua frota", "In your fleet", "En tu flota", "In deiner Flotte", "Dans votre flotte",
                            "В вашем флоте", "Di armadamu", "保有中", "보유 중", "已在艦隊中", "已在舰队中"],
    "store.premium_lore_hippocampus": [
        "O corcel de Poseidon, refeito em oricalco e luz.", "Poseidon's steed, reforged in orichalcum and light.",
        "El corcel de Poseidón, forjado en oricalco y luz.", "Poseidons Ross, neu geschmiedet aus Orichalkum und Licht.",
        "Le coursier de Poséidon, reforgé d'orichalque et de lumière.", "Скакун Посейдона, перекованный из орихалка и света.",
        "Kuda Poseidon, ditempa ulang dari orikalkum dan cahaya.", "オリハルコンと光で鍛え直したポセイドンの駿馬。",
        "오리할콘과 빛으로 다시 벼린 포세이돈의 준마.", "以山銅與光重鑄的波賽頓神駒。", "以山铜与光重铸的波塞冬神驹。"],
    "store.premium_lore_nereid": [
        "Asa de madrepérola das ninfas do mar.", "A mother-of-pearl wing of the sea nymphs.",
        "Ala de nácar de las ninfas del mar.", "Perlmuttschwinge der Meeresnymphen.",
        "Aile de nacre des nymphes marines.", "Перламутровое крыло морских нимф.",
        "Sayap mutiara para peri laut.", "海のニンフの真珠層の翼。", "바다 님프의 자개 날개.",
        "海仙女的珍珠母之翼。", "海仙女的珍珠母之翼。"],
    "store.premium_lore_amphitrite": [
        "A nau da rainha dos mares, em turquesa e ouro.", "The sea queen's flagship, in turquoise and gold.",
        "La nave de la reina de los mares, en turquesa y oro.", "Das Flaggschiff der Meereskönigin, in Türkis und Gold.",
        "Le vaisseau de la reine des mers, turquoise et or.", "Флагман царицы морей в бирюзе и золоте.",
        "Kapal sang ratu lautan, berwarna pirus dan emas.", "海の女王の旗艦、ターコイズと金。",
        "청록과 금빛의 바다 여왕의 기함.", "海之女王的旗艦，綠松與金。", "海之女王的旗舰，绿松与金。"],
    "ships.premium_lock": [
        "Nave premium: à venda na Loja.", "Premium ship: sold in the Shop.", "Nave premium: a la venta en la Tienda.",
        "Premium-Schiff: im Shop erhältlich.", "Vaisseau premium : en vente dans la Boutique.",
        "Премиум-корабль: продаётся в магазине.", "Kapal premium: dijual di Toko.", "プレミアム機：ショップで販売中。",
        "프리미엄 기체: 상점에서 판매 중.", "高級戰機：商店販售中。", "高级战机：商店有售。"],
    "ships.see_shop": ["Ver na Loja", "See in the Shop", "Ver en la Tienda", "Im Shop ansehen", "Voir dans la Boutique",
                       "Открыть в магазине", "Lihat di Toko", "ショップで見る", "상점에서 보기", "到商店查看", "去商店查看"],
}
