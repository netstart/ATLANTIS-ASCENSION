class_name Ads
extends RefCounted
## Anúncio recompensado OPCIONAL (plano mestre 17): só o jogador pede, nunca durante a missão, e a
## recompensa é pequena (reviver 1 vez, dobrar créditos, baú em dobro). Sem o plugin do AdMob (Fase 4)
## o anúncio é SIMULADO: a recompensa sai na hora e nenhum anúncio é exibido. Na Steam e para quem
## apoiou não há anúncio: a recompensa é concedida direto (`Store.ads_allowed` falso).


## Pede um anúncio recompensado; `done(granted: bool)` é chamado no quadro seguinte.
static func show_rewarded(profile: Dictionary, done: Callable) -> void:
	var granted := not Store.ads_allowed(profile) or Store.simulated()
	done.call_deferred(granted)
