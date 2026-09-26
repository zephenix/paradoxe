class_name Cutscene
extends Node
## Une cinématique (J7, PLAN §5.12), écrite comme un petit scénario : une suite
## d'étapes qu'on attend l'une après l'autre (await), par exemple :
##
##     func run(ctx: CutscenePlayer) -> void:
##         await ctx.wait(1.0)                      # un temps
##         await ctx.walk(marek, 900.0)              # Marek marche jusqu'à x = 900
##         marek.visual.play(&"touch_pendant")        # un geste
##         AudioManager.play_sfx(&"companion_surprise", marek.global_position)
##
## Analogie VBA : c'est une macro qu'on lit de haut en bas ; « await » attend
## que l'étape soit finie avant de passer à la ligne suivante.
##
## Deux fonctions à redéfinir :
##   - run(ctx) : le déroulé, étape par étape ;
##   - finish(ctx) : l'état FINAL du monde (qui est où, qui a quoi). Il est
##     appelé à la fin, même si le joueur a passé la cinématique : passer ne
##     doit jamais laisser le jeu dans un état incohérent.
## Les attentes du lecteur (ctx.wait, ctx.walk…) se terminent aussitôt quand le
## joueur passe la cinématique.

## Cinématique à enchaîner juste après (sans rendre la main entre les deux).
@export var next: NodePath
## Ne se joue qu'une fois.
@export var play_once: bool = true

## Vrai une fois jouée (ou passée).
var played: bool = false


func run(_ctx: CutscenePlayer) -> void:
	pass


func finish(_ctx: CutscenePlayer) -> void:
	pass


## La cinématique suivante (ou null).
func next_cutscene() -> Cutscene:
	return get_node_or_null(next) as Cutscene if not next.is_empty() else null
