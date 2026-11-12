"""The converter's named switches: every place where the recorded target text leaves a choice open.

Each switch has the template's own behaviour as its default. A record stores the value of every switch, so a
conversion can be made again, and a later proof run can change one switch and convert again.
"""

# name: (default, allowed values or None for free text, what it decides, what settles it)
SWITCHES = {
    # --- what the server gives the template (open point 2 of the target-text folder) ---
    "enable_thinking": (
        "unset", ("unset", "true", "false"),
        "the template variable enable_thinking; unset leaves the template's own default, thinking on",
        "the server's preset, read from a live server",
    ),
    "reasoning_effort": (
        "unset", ("unset", "xhigh", "high", "medium", "low"),
        "the template variable reasoning_effort; unset leaves the template's own default, xhigh, and its sentence "
        "at the top of the system turn",
        "the server's preset, read from a live server",
    ),
    "preserve_thinking": (
        "unset", ("unset", "true", "false"),
        "the template variable preserve_thinking; unset leaves the template's own default, earlier thinking kept. "
        "With false the template drops the thinking of answers before the last user message. A session has one "
        "user message, the description, so its text is the same either way; a conversation with a later user "
        "message would no longer be one text that only grows, and the converter refuses it",
        "the server's preset, read from a live server",
    ),
    # --- the prompt's exact bytes (open point 1) ---
    "begin_token": (
        "", None,
        "text put before the first turn; the template writes none. The server reported the begin token "
        "<|endoftext|>",
        "the server's own rendering of one request",
    ),
    "trim": (
        "jinja2", ("jinja2", "c_isspace"),
        "which characters the template's trim removes at the ends of every text: jinja2 removes all Unicode white "
        "space, c_isspace only space, tab, line feed, vertical tab, form feed and carriage return (what the "
        "server's source does)",
        "the server's own rendering of a text that ends in such a character",
    ),
    "json_item_separator": (
        ", ", None,
        "the text between two items when the template writes a value as JSON (tool lines, parameters that are "
        "not text)",
        "the server's own rendering of the tool lines",
    ),
    "json_key_separator": (
        ": ", None,
        "the text after a key when the template writes a value as JSON",
        "the server's own rendering of the tool lines",
    ),
    "json_ensure_ascii": (
        "false", ("false", "true"),
        "whether non-ASCII characters inside a JSON value are written as \\uXXXX",
        "the server's own rendering of a parameter that holds non-ASCII text",
    ),
    "json_escape_html": (
        "false", ("false", "true"),
        "whether <, >, & and ' inside a JSON value are written as \\uXXXX, as Jinja2's stock filter does",
        "the server's own rendering of the tool lines",
    ),
    "jinja_trim_blocks": (
        "true", ("true", "false"),
        "the template engine's trim_blocks setting, which decides the white space between the template's blocks",
        "the server's own rendering of one request",
    ),
    "jinja_lstrip_blocks": (
        "true", ("true", "false"),
        "the template engine's lstrip_blocks setting, which decides the white space between the template's blocks",
        "the server's own rendering of one request",
    ),
    # --- a tuned file's template (open point 6) ---
    "strip_generation_tags": (
        "true", ("true", "false"),
        "remove the maker's generation tags before rendering; they write nothing, and Jinja2 does not know them",
        "the server's rendering of the tuned file",
    ),
    # --- how the model's calls are written back (open point 4) ---
    "param_order": (
        "stream", ("stream", "sorted"),
        "the order of a call's parameters: stream is the order the teacher wrote, read from the reply stream; "
        "sorted is the alphabetical order of the stored requests",
        "the model's raw reply on a live server, beside the template's writing of the same call",
    ),
    "integral_floats": (
        "as_integers", ("as_integers", "keep"),
        "a number the teacher wrote with a fraction of zero (120.0): as_integers writes 120, as the agent's "
        "JSON.stringify does before the server sees it; keep writes 120.0",
        "one such call sent through the agent to a live server",
    ),
    # --- the shape of a message where the bench's records hold no example (the text is the same either way) ---
    "no_thinking_field": (
        "omit", ("omit", "empty", "null"),
        "the reasoning_content key of an answer without thinking: left out, an empty text, or null",
        "one answer without thinking recorded on the bench's route",
    ),
    "final_tool_calls_field": (
        "omit", ("omit", "empty"),
        "the tool_calls key of an answer without calls (the closing words): left out, or an empty list",
        "the agent's request after a closing answer, recorded on the bench's route",
    ),
    # --- a setting, not a question: where the model stops ---
    "end_token": (
        "<|im_end|>", None,
        "the token that ends a turn, as the server reported it; the model's own writing in a turn ends with it",
        "recorded: the server's report in the target-text folder",
    ),
}


def defaults():
    return {name: spec[0] for name, spec in SWITCHES.items()}


def resolve(given=None):
    """The full set of switch values: the defaults with the given ones laid over them."""
    values = defaults()
    for name, value in (given or {}).items():
        if name not in SWITCHES:
            raise ValueError("unknown switch %r; known: %s" % (name, ", ".join(sorted(SWITCHES))))
        allowed = SWITCHES[name][1]
        if not isinstance(value, str):
            raise ValueError("switch %s takes text, got %r" % (name, value))
        if allowed is not None and value not in allowed:
            raise ValueError("switch %s takes one of %s, got %r" % (name, ", ".join(allowed), value))
        values[name] = value
    return values


def parse_assignments(items):
    """--switch name=value pairs. A value that starts with a double quote is read as a JSON string."""
    import json

    given = {}
    for item in items or []:
        name, sign, value = item.partition("=")
        if not sign:
            raise ValueError("a switch is written name=value, got %r" % item)
        if value.startswith('"'):
            value = json.loads(value)
        given[name] = value
    return given
