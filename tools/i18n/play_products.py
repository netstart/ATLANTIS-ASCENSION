"""Textos da ficha dos produtos premium e dos pacotes de Pérolas no Play Console (lidos por tools/play_products.py; não vão para o jogo,
por isso ficam fora de MODULES em tools/build_i18n.py). O resto vem dos textos do jogo em command_premium.py
(nome, frase, "joga como" e "visual exclusivo"), ui.py (nome da nave de origem) e command_iap.py (a frase e a nota
dos pacotes de Pérolas).
Limites da Play: título até 55 caracteres, descrição até 200 (tools/play_products.py confere).
Ordem: pt_BR, en, es, de, fr, ru, id, ja, ko, zh_TW, zh_CN.
"""

STRINGS = {
    "play.premium_title": ["Nave premium: %s", "Premium ship: %s", "Nave premium: %s", "Premium-Schiff: %s",
                           "Vaisseau premium : %s", "Премиум-корабль: %s", "Kapal premium: %s", "プレミアム機：%s",
                           "프리미엄 기체: %s", "高級戰機：%s", "高级战机：%s"],
    "play.premium_fleet_title": ["Frota premium: 3 naves", "Premium fleet: 3 ships", "Flota premium: 3 naves",
                                 "Premium-Flotte: 3 Schiffe", "Flotte premium : 3 vaisseaux", "Премиум-флот: 3 корабля",
                                 "Armada premium: 3 kapal", "プレミアム艦隊：3機", "프리미엄 함대: 3대", "高級艦隊：3 架戰機",
                                 "高级舰队：3 架战机"],
    "play.premium_fleet_ships": ["Inclui %s.", "Includes %s.", "Incluye %s.", "Enthält %s.", "Comprend %s.",
                                 "Включает: %s.", "Termasuk %s.", "%sを収録。", "%s 포함.", "包含%s。", "包含%s。"],
    "play.list_and": [" e ", " and ", " y ", " und ", " et ", " и ", " dan ", "、", ", ", "、", "、"],
    "play.pearls_title": ["%s Pérolas", "%s Pearls", "%s Perlas", "%s Perlen", "%s Perles", "%s жемчуга",
                          "%s Mutiara", "真珠 %s 個", "진주 %s개", "珍珠 %s 顆", "珍珠 %s 颗"],
    "play.remove_ads_title": ["Remover anúncios", "Remove ads", "Quitar anuncios", "Werbung entfernen",
                              "Supprimer les publicités", "Убрать рекламу", "Hapus iklan", "広告を削除", "광고 제거",
                              "移除廣告", "移除广告"],
}
