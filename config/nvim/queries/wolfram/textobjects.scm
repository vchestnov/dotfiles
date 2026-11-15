; Wolfram textobjects for mini.ai / tree-sitter-based selection.
; Focus on constructs with stable inner regions.

(set_top) @assignment.outer
(set_delayed_top) @assignment.outer
(up_set_top) @assignment.outer
(up_set_delayed_top) @assignment.outer

(set_top
  .
  (_)
  .
  (set_operator)
  .
  (_) @assignment.inner)

(set_delayed_top
  .
  (_)
  .
  (set_delayed_operator)
  .
  (_) @assignment.inner)

(up_set_top
  .
  (_)
  .
  (up_set_operator)
  .
  (_) @assignment.inner)

(up_set_delayed_top
  .
  (_)
  .
  (up_set_delayed_operator)
  .
  (_) @assignment.inner)

(function_anonymous_top) @function.outer
(function_arrow_top) @function.outer

(function_anonymous_top
  .
  (_)
  .
  (function_anonymous_operator)
  .
  (_) @function.inner)

(function_arrow_top
  .
  (_)
  .
  (function_arrow_operator)
  .
  (_) @function.inner)
