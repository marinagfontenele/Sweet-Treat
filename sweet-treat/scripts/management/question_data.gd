#class_name QuestionData
#extends RefCounted
#
#var id: String
#var text: String
#
#func _init(question_text: String, question_id: String = "") -> void:
	#text = question_text
#
	#if question_id.is_empty():
		#id = str(Time.get_ticks_usec()) + "_" + str(randi())
	#else:
		#id = question_id
