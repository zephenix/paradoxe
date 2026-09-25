class_name ErrorCatcher
extends Logger
## Intercepte les erreurs et avertissements du moteur pendant les tests.
##
## Sans lui, une erreur de script (variable inconnue, nœud introuvable…) serait
## simplement affichée dans la console et le test passerait quand même.
## Le lanceur de tests enregistre ce « Logger » auprès du moteur
## (OS.add_logger) et fait échouer tout test pendant lequel une erreur survient.
##
## Attention : le moteur peut appeler ces fonctions depuis plusieurs fils
## d'exécution (threads) à la fois, d'où le verrou (Mutex).

var _mutex := Mutex.new()
var _errors: PackedStringArray = []
var _warnings: PackedStringArray = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var message: String = rationale if not rationale.is_empty() else code
	# Si l'erreur vient d'un script (push_error, erreur d'exécution…), on préfère
	# indiquer la ligne GDScript en cause plutôt que le fichier C++ du moteur.
	for backtrace in script_backtraces:
		if backtrace != null and backtrace.get_frame_count() > 0:
			file = backtrace.get_frame_file(0)
			line = backtrace.get_frame_line(0)
			function = backtrace.get_frame_function(0)
			break
	var entry: String = "%s (%s:%d, %s)" % [message, file, line, function]
	_mutex.lock()
	if error_type == ERROR_TYPE_WARNING:
		_warnings.append(entry)
	else:
		_errors.append(entry)
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass  # les simples messages (print) ne nous intéressent pas


## Erreurs reçues depuis le dernier clear().
func errors() -> PackedStringArray:
	_mutex.lock()
	var copy: PackedStringArray = _errors.duplicate()
	_mutex.unlock()
	return copy


## Avertissements reçus depuis le dernier clear().
func warnings() -> PackedStringArray:
	_mutex.lock()
	var copy: PackedStringArray = _warnings.duplicate()
	_mutex.unlock()
	return copy


func clear() -> void:
	_mutex.lock()
	_errors.clear()
	_warnings.clear()
	_mutex.unlock()
