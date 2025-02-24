@tool
class_name DialogicChoiceEvent
extends DialogicEvent

## Event that allows adding choices. Needs to go after a text event (or another choices EndBranch).

enum ElseActions {HIDE=0, DISABLE=1, DEFAULT=2}


### Settings
## The text that is displayed on the choice button.
var text :String = ""
## If not empty this condition will determine if this choice is active.
var condition: String = ""
## Determines what happens if  [condition] is false. Default will use the action set in the settings.
var else_action: = ElseActions.DEFAULT
## The text that is displayed if [condition] is false and [else_action] is Disable.
## If empty [text] will be used for disabled button as well.
var disabled_text: String = ""

#endregion

var regex := RegEx.create_from_string(r'- (?<text>(?(?=\[if)|.)*)(\[if (?<condition>([^\]\[]|\[[^\]]*\])+)])?\s?(\s*\[(?<shortcode>.*)\])?')

#region EXECUTION
################################################################################

func _execute() -> void:

	if dialogic.Choices.is_question(dialogic.current_event_idx):
		dialogic.Choices.show_current_question(false)
		dialogic.current_state = dialogic.States.AWAITING_CHOICE

#endregion


#region INITIALIZE
################################################################################

func _init() -> void:
	event_name = "Choice"
	set_default_color('Color3')
	event_category = "Flow"
	event_sorting_index = 0
	can_contain_events = true
	wants_to_group = true


# return a control node that should show on the END BRANCH node
func get_end_branch_control() -> Control:
	return load(get_script().resource_path.get_base_dir().path_join('ui_choice_end.tscn')).instantiate()
#endregion


#region SAVING/LOADING
################################################################################

func to_text() -> String:
	var result_string := ""

	result_string = "- "+text.strip_edges()
	if condition:
		result_string += " [if "+condition+"]"


	var shortcode := '['
	if else_action == ElseActions.HIDE:
		shortcode += 'else="hide"'
	elif else_action == ElseActions.DISABLE:
		shortcode += 'else="disable"'

	if disabled_text:
		shortcode += " alt_text="+'"'+disabled_text+'"'

	if len(shortcode) > 1:
		result_string += shortcode + "]"
	return result_string


func from_text(string:String) -> void:
	var result := regex.search(string.strip_edges())
	if result == null:
		return
	text = result.get_string('text')
	condition = result.get_string('condition')
	if result.get_string('shortcode'):
		var shortcode_params := parse_shortcode_parameters(result.get_string('shortcode'))
		else_action = {
			'default':ElseActions.DEFAULT,
			'hide':ElseActions.HIDE,
			'disable':ElseActions.DISABLE}.get(shortcode_params.get('else', ''), ElseActions.DEFAULT)

		disabled_text = shortcode_params.get('alt_text', '')


func is_valid_event(string:String) -> bool:
	if string.strip_edges().begins_with("-"):
		return true
	return false

#endregion

#region TRANSLATIONS
################################################################################

func _get_translatable_properties() -> Array:
	return ['text', 'disabled_text']


func _get_property_original_translation(property:String) -> String:
	match property:
		'text':
			return text
		'disabled_text':
			return disabled_text
	return ''
#endregion


#region EDITOR REPRESENTATION
################################################################################

func build_event_editor() -> void:
	add_header_edit("text", ValueType.SINGLELINE_TEXT, {'autofocus':true})
	add_body_edit("condition", ValueType.CONDITION, {'left_text':'if '})
	add_body_edit("else_action", ValueType.FIXED_OPTIONS, {'left_text':'else ',
		'options': [
			{
				'label': 'Default',
				'value': ElseActions.DEFAULT,
			},
			{
				'label': 'Hide',
				'value': ElseActions.HIDE,
			},
			{
				'label': 'Disable',
				'value': ElseActions.DISABLE,
			}
		]}, '!condition.is_empty()')
	add_body_edit("disabled_text", ValueType.SINGLELINE_TEXT, {
			'left_text':'Disabled text:',
			'placeholder':'(Empty for same)'}, 'allow_alt_text()')


func allow_alt_text() -> bool:
	return condition and (
		else_action == ElseActions.DISABLE or
		(else_action == ElseActions.DEFAULT and
		ProjectSettings.get_setting("dialogic/choices/def_false_behaviour", 0) == 1))
#endregion


#region  CODE COMPLETION
################################################################################

func _get_code_completion(CodeCompletionHelper:Node, TextNode:TextEdit, line:String, word:String, symbol:String) -> void:
	line = CodeCompletionHelper.get_line_untill_caret(line)

	if !'[if' in line:
		if symbol == '{':
			CodeCompletionHelper.suggest_variables(TextNode)
		return

	if symbol == '[':
		if !'[if' in line and line.count('[') - line.count(']') == 1:
			TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, 'if', 'if ', TextNode.syntax_highlighter.code_flow_color)
		elif '[if' in line:
			TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, 'else', 'else="', TextNode.syntax_highlighter.code_flow_color)
	if symbol == ' ' and '[else' in line:
		TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, 'alt_text', 'alt_text="', event_color.lerp(TextNode.syntax_highlighter.normal_color, 0.5))
	elif symbol == '{':
		CodeCompletionHelper.suggest_variables(TextNode)
	if (symbol == '=' or symbol == '"') and line.count('[') > 1 and !'" ' in line:
		TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, 'default', "default", event_color.lerp(TextNode.syntax_highlighter.normal_color, 0.5), null, '"')
		TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, 'hide', "hide", event_color.lerp(TextNode.syntax_highlighter.normal_color, 0.5), null, '"')
		TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, 'disable', "disable", event_color.lerp(TextNode.syntax_highlighter.normal_color, 0.5), null, '"')
#endregion


#region  SYNTAX HIGHLIGHTING
################################################################################

func _get_syntax_highlighting(Highlighter:SyntaxHighlighter, dict:Dictionary, line:String) -> Dictionary:
	var result := regex.search(line)

	dict[0] = {'color':event_color}

	var condition_begin := result.get_start("condition")
	var condition_end := result.get_end("condition")

	var shortcode_begin := result.get_start("shortcode")

	dict = Highlighter.color_region(dict, event_color.lerp(Highlighter.variable_color, 0.5), line, '{','}', 0, condition_begin, event_color)

	if condition_begin > 0:
		var from := line.find('[if')
		dict[from] = {"color":Highlighter.normal_color}
		dict[from+1] = {"color":Highlighter.code_flow_color}
		dict[condition_begin] = {"color":Highlighter.normal_color}
		dict = Highlighter.color_condition(dict, line, condition_begin, condition_end)
		if shortcode_begin:
			dict = Highlighter.color_shortcode_content(dict, line, shortcode_begin, 0, event_color)
	return dict
#endregion

