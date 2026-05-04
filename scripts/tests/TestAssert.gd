extends RefCounted
class_name TestAssert

var passes: int = 0
var failures: Array[String] = []

func that(condition: bool, message: String) -> void:
	if condition:
		passes += 1
	else:
		failures.append(message)

func eq(actual, expected, message: String) -> void:
	if actual == expected:
		passes += 1
	else:
		failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func neq(actual, not_expected, message: String) -> void:
	if actual != not_expected:
		passes += 1
	else:
		failures.append("%s | unexpected=%s actual=%s" % [message, str(not_expected), str(actual)])

func gt(actual, minimum, message: String) -> void:
	if actual > minimum:
		passes += 1
	else:
		failures.append("%s | actual=%s should exceed %s" % [message, str(actual), str(minimum)])

func gte(actual, minimum, message: String) -> void:
	if actual >= minimum:
		passes += 1
	else:
		failures.append("%s | actual=%s should be >= %s" % [message, str(actual), str(minimum)])

func between(actual, low, high, message: String) -> void:
	if actual >= low and actual <= high:
		passes += 1
	else:
		failures.append("%s | actual=%s not in [%s, %s]" % [message, str(actual), str(low), str(high)])

func report(label: String) -> void:
	if failures.is_empty():
		print("%s PASS (%d checks)" % [label, passes])
		return
	push_error("%s FAIL (%d failures)" % [label, failures.size()])
	for failure in failures:
		push_error(failure)
