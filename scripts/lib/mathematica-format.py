#!/usr/bin/env python3
"""Format Wolfram source passed as a JSON request on stdin."""

import json
import sys

LITERAL_TOKENS = ('<|', '|>', '[[', ']]', '::', ';;', '++', '--', '*^', '>>>', '>>', '<<')
OPERATORS = (
    '=!=', '===', '//.', '@@@', '^:=', '|->', ':=', '->', ':>', '<=', '>=',
    '==', '!=', '+=', '-=', '*=', '/=', '^=', '=.', '&&', '||', '//', '/.',
    '/@', '/;', '/:', '/*', '@@', '**', '<>'
)
SINGLE_OPERATORS = set('=<>+-*/@|')
NO_SPACE_AFTER = set('([{,')
NO_SPACE_BEFORE = set(')]},;[')
NO_SPACE_AFTER_COMMA = set(')]},')


def trim_out(out):
    while out:
        stripped = out[-1].rstrip()
        if stripped:
            out[-1] = stripped
            return
        out.pop()


def out_ends_space(out):
    return bool(out and out[-1] and out[-1][-1].isspace())


def previous_non_space(out):
    for token in reversed(out):
        for char in reversed(token):
            if not char.isspace():
                return char
    return ''


def append_space(out):
    if out and not out_ends_space(out):
        out.append(' ')


def next_non_space_index(text, index):
    while index < len(text) and text[index].isspace():
        index += 1
    return index


def starts_with_any(text, index, tokens):
    for token in tokens:
        if text.startswith(token, index):
            return token
    return ''


def operator_at(text, index):
    operator = starts_with_any(text, index, OPERATORS)
    if operator:
        return operator

    char = text[index]
    return char if char in SINGLE_OPERATORS else ''


def suppress_space_between(previous, next_char):
    return previous in NO_SPACE_AFTER or next_char in NO_SPACE_BEFORE


def unary_sign(out):
    previous = previous_non_space(out)
    return not previous or previous in '([{,=<>!+-*/@|&^'


def format_line(line, comment_depth, tabstop):
    line = line.expandtabs(tabstop)
    out = []
    index = 0
    in_string = False
    escaped = False
    skip_space_after_sign = False

    while index < len(line):
        char = line[index]
        pair = line[index:index + 2]

        if comment_depth > 0:
            if pair == '(*':
                out.append(pair)
                index += 2
                comment_depth += 1
                continue
            if pair == '*)':
                out.append(pair)
                index += 2
                comment_depth -= 1
                continue

            out.append(char)
            index += 1
            continue

        if in_string:
            out.append(char)

            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == '"':
                in_string = False

            index += 1
            continue

        if pair == '(*':
            out.append(pair)
            index += 2
            comment_depth += 1
            continue

        if char == '"':
            out.append(char)
            index += 1
            in_string = True
            skip_space_after_sign = False
            continue

        if char.isspace():
            next_index = next_non_space_index(line, index)
            next_char = line[next_index] if next_index < len(line) else ''
            previous = previous_non_space(out)

            if (
                not skip_space_after_sign
                and previous
                and next_char
                and not suppress_space_between(previous, next_char)
            ):
                append_space(out)

            index = next_index
            continue

        literal = starts_with_any(line, index, LITERAL_TOKENS)
        if literal:
            if literal in (';;', '<|'):
                out.append(literal)
            else:
                trim_out(out)
                out.append(literal)
            index += len(literal)
            skip_space_after_sign = False
            continue

        operator = operator_at(line, index)
        if operator:
            if operator in ('+', '-') and unary_sign(out):
                out.append(operator)
                skip_space_after_sign = True
            else:
                trim_out(out)
                if out:
                    append_space(out)
                out.append(operator)
                out.append(' ')
                skip_space_after_sign = False

            index += len(operator)
            continue

        if char == ',':
            trim_out(out)
            out.append(',')
            next_index = next_non_space_index(line, index + 1)
            next_char = line[next_index] if next_index < len(line) else ''

            if next_char and next_char not in NO_SPACE_AFTER_COMMA:
                out.append(' ')

            index += 1
            skip_space_after_sign = False
            continue

        if char == ';' or char in ')]}':
            trim_out(out)
            out.append(char)
            index += 1
            skip_space_after_sign = False
            continue

        if char == '[':
            trim_out(out)
            out.append(char)
            index += 1
            skip_space_after_sign = False
            continue

        out.append(char)
        index += 1
        skip_space_after_sign = False

    return ''.join(out).rstrip(), comment_depth


def line_depth_delta(line, comment_depth):
    index = 0
    delta = 0
    in_string = False
    escaped = False

    while index < len(line):
        char = line[index]
        pair = line[index:index + 2]

        if comment_depth > 0:
            if pair == '(*':
                comment_depth += 1
                index += 2
                continue
            if pair == '*)':
                comment_depth -= 1
                index += 2
                continue

            index += 1
            continue

        if in_string:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == '"':
                in_string = False

            index += 1
            continue

        if pair == '(*':
            comment_depth += 1
            index += 2
            continue

        if pair == '<|':
            delta += 1
            index += 2
            continue

        if pair == '|>':
            delta -= 1
            index += 2
            continue

        if char == '"':
            in_string = True
        elif char in '[{(':
            delta += 1
        elif char in ']})':
            delta -= 1

        index += 1

    if delta > 0:
        delta = 1

    return delta, comment_depth


def leading_close_depth(line, comment_depth):
    if comment_depth > 0 or line.startswith('(*'):
        return 0

    if line.startswith('|>'):
        return 1

    depth = 0
    for char in line:
        if char in ']})':
            depth += 1
        elif char == ',':
            return max(depth, 1)
        else:
            return depth

    return depth


def format_buffer(lines, tabstop, shiftwidth):
    comment_depth = 0
    formatted = []

    for line in lines:
        line, comment_depth = format_line(line.lstrip(), comment_depth, tabstop)
        formatted.append(line)

    depth = 0
    comment_depth = 0
    indented = []

    for line in formatted:
        stripped = line.lstrip()

        if not stripped:
            indented.append('')
            continue

        indent_depth = max(0, depth - leading_close_depth(stripped, comment_depth))
        line = (' ' * (indent_depth * shiftwidth)) + stripped
        indented.append(line)

        delta, comment_depth = line_depth_delta(line, comment_depth)
        depth = max(0, depth + delta)

    return indented


def main():
    request = json.load(sys.stdin)
    lines = format_buffer(request['lines'], request['tabstop'], request['shiftwidth'])
    json.dump(lines, sys.stdout)
    sys.stdout.write('\n')


if __name__ == '__main__':
    main()
