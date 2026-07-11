" Provide a fix for Markdown indented code block syntax highlighting so that
" deeply nested list items are no longer mistaken for code blocks.
" Ported from rstliteralblockfix.vim by Fable.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" The stock syntax/markdown.vim detects indented code blocks via:
"
"   syn region markdownCodeBlock start="^\n\( \{4,}\|\t\)" end="^\ze \{,3}\S.*$" keepend
"
" That is: after an empty line, any line indented four or more spaces (or a
" tab) begins a code block, which continues until a line indented three or
" fewer spaces appears.  This rule is context-free; it knows nothing about
" list nesting.  But Markdown measures code block indentation relative to the
" content of the containing list item.  With two-space nesting:
"
"   - first level
"
"     - second level
"
"       - third level
"
" "- third level" is indented four spaces, so the stock rule highlights it
" (and anything nested more deeply) as markdownCodeBlock, limiting correct
" highlighting to two levels of bullets.  Similarly, the stock
" markdownListMarker and markdownOrderedListMarker patterns allow at most
" four spaces (or one tab) of indentation before the bullet or number, so
" even the markers of deeper items would go unhighlighted.
"
" What Markdown actually specifies (approximately; see CommonMark):
"
"   - The "content indentation" of a list item is the width of its leading
"     whitespace, plus its marker ("-", "+", "*", "1.", "23)", ...), plus the
"     whitespace following the marker.
"
"   - Text indented at least to the content indentation continues the item.
"
"   - An indented code block inside the item must be indented at least four
"     columns *beyond* the content indentation, and it ends when a non-blank
"     line dedents below that.
"
" So, to decide whether an indented chunk is code, we need the indentation of
" the list item (or paragraph) that precedes it -- context that a syntax
" region cannot normally see.  The same problem arises for reStructuredText
" literal blocks, and scripts/rstliteralblockfix.vim solves it with two
" tricks that are reused here (see that file for the full derivation):
"
"   1. A zero-width look-behind ('\@<=') in the region's 'start=' pattern
"      matches the *previous* line and captures pieces of it into external
"      groups \z1 ... \z9, which remain available in the region's 'end='
"      pattern.
"
"   2. There is no direct way to convert a captured list marker such as
"      "12." into an equal-width run of spaces.  However, a marker with a
"      known length of n characters can be matched together with \z( \)
"      capturing the single space that must follow it; the 'end=' pattern
"      can then repeat that captured group n+1 times to produce exactly the
"      width of "marker plus one space" in spaces.  Grouping markers by
"      length -- bullets are 1 character; enumerations are 2 through 7
"      characters -- and giving each length class its own \z( \) group
"      covers all cases, because groups belonging to classes that did not
"      participate in the match expand to the empty string.
"
" The resulting capture layout (parallel to the rst fix):
"
"   \z1  leading whitespace
"   \z2  one space, if a 1-character bullet ("-", "+", "*") matched
"   \z3  one space, if a 2-character enumeration ("1.", "1)") matched
"   \z4  one space, if a 3-character enumeration ("12.", "12)") matched
"   ...
"   \z8  one space, if a 7-character enumeration ("123456.") matched
"   \z9  any additional whitespace after the marker's first space
"
" and the content indentation (the "threshold") is reproduced in 'end=' by
" the concatenation:
"
"   \z1  \z2\z2  \z3\z3\z3  \z4\z4\z4\z4  ...  \z8{8 times}  \z9
"
" Differences from the reStructuredText fix:
"
"   - reST literal blocks are announced by "::" at the end of a line, so the
"     rst region starts only after such lines.  Markdown has no announcing
"     token: an indented code block may follow *any* non-blank line (a list
"     item line or an ordinary paragraph line) plus a blank line.  Therefore
"     the entire marker portion of the look-behind is optional, and the
"     anchor is simply the last non-blank line before the blank line.  For a
"     plain paragraph line, the threshold is just its leading whitespace
"     (\z1); this is correct for continuation paragraphs of a list item as
"     well, because such paragraphs sit exactly at the content indentation.
"
"   - reST literal mode requires indentation merely *greater than* the
"     threshold; Markdown code requires at least threshold + 4 spaces (or
"     threshold + a tab).  Hence the 'end=' pattern here is:
"
"       ^\%(<threshold> \{4}\|<threshold>\t\)\@!
"
"     i.e. the region ends at the first non-blank line that is not indented
"     to at least threshold + 4.  Blank lines are passed over with
"     skip='^\s*$', as in the rst fix.
"
"   - The region starts after *every* "non-blank line, blank line" pair,
"     even when no code follows.  In that case the first non-blank line
"     after the blank fails the indentation test, the zero-width 'end='
"     pattern matches at its first column, and the region closes having
"     covered only the blank line(s) -- which is invisible.  This is not
"     wasted effort: the stock markdownCodeBlock rule's 'start=' pattern
"     begins with "^\n", so it can only fire on an empty line, and every
"     empty line that follows a non-blank line is now consumed by this
"     region.  The stock rule is thereby neutralized wherever this rule has
"     better information, without having to remove it (it still covers the
"     corner case of an indented chunk at the very top of the file, where
"     no anchor line exists).  Because this region's start match begins
"     earlier in the buffer (at the newline ending the anchor line) than
"     any match beginning on the empty line itself, it wins regardless of
"     definition order (see :help syn-priority).
"
" In addition to the region, "MdCodeBlockFix on" extends markdownListMarker
" and markdownOrderedListMarker to accept any amount of leading whitespace,
" so the markers of deeply nested items are highlighted.  Lines that truly
" belong to a code block cannot receive these marker highlights, because
" contained items do not match inside the markdownCodeBlock region.
"
" Known limitations:
"
"   - Enumerations longer than seven characters (more than six digits) are
"     not converted into threshold spaces.
"
"   - A code chunk separated from its anchor line by the anchor's own code
"     block (code, blank, code) is handled, but an indented chunk whose
"     anchor line is the first line of the file after leading blank lines
"     falls back to the stock rule.
"
"   - "MdCodeBlockFix off" restores the stock rules, but if
"     g:markdown_fenced_languages is in use, the restored generic fenced
"     rules take precedence over the per-language fenced regions; use
"     ":set syntax=markdown" for a perfect reset in that case.

" Build up s:pat, a pattern to detect the start of markdownCodeBlock.

" Begin the look-behind group for the entire anchor line:
let s:pat = '\('

" \z1 captures optional leading whitespace:
let s:pat .= '^\z(\s*\)'

" Begin optional capture of a bullet or enumeration:
let s:pat .= '\('

" n=1: a bullet character, with \z2 capturing the following space:
let s:pat .= '[-+*]\z( \)'

" s:n is the number of non-whitespace characters in the enumeration
" ("1." has two, "12)" has three, ...).  Iterate from 2 through 7,
" capturing the following space into \z3 through \z8:
let s:n = 2
while s:n <= 7
    let s:pat .= '\|\d\{' . (s:n - 1) . '}[.)]\z( \)'
    let s:n += 1
endwhile

" End optional capture of bullet or enumeration:
let s:pat .= '\)\?'

" \z9 captures any extra spaces after the marker's first space:
let s:pat .= '\z( *\)'

" Require the anchor line to be non-blank; then close the look-behind:
let s:pat .= '\S.*\)\@<='

" The consumed text: the newline ending the anchor line plus one blank line.
" The region therefore begins just before the first candidate code line:
let s:pat .= '\n\s*\n'

" Build up the threshold whitespace, s:threshold: the anchor's content
" indentation with the marker converted to spaces via repeated \z groups.
let s:threshold = '\z1'
let s:threshold .= '\z2\z2'
let s:threshold .= '\z3\z3\z3'
let s:threshold .= '\z4\z4\z4\z4'
let s:threshold .= '\z5\z5\z5\z5\z5'
let s:threshold .= '\z6\z6\z6\z6\z6\z6'
let s:threshold .= '\z7\z7\z7\z7\z7\z7\z7'
let s:threshold .= '\z8\z8\z8\z8\z8\z8\z8\z8'
let s:threshold .= '\z9'

" End at the first line lacking threshold + 4 spaces (or threshold + tab) of
" indentation; blank lines are skipped via skip=:
let s:end_pat = '^\%(' . s:threshold . ' \{4}\|' . s:threshold . '\t\)\@!'

" Build up the 'syn' command:
let s:syn = 'syn region markdownCodeBlock'
let s:syn .= ' start="' . s:pat . '"'
let s:syn .= ' skip="^\s*$"'
let s:syn .= ' end="' . s:end_pat . '"'
let s:syn .= ' keepend'

function! MdCodeBlockFix(on_off)
    if a:on_off == "on"
        execute s:syn
        " Allow list markers at any depth of indentation (also accepting the
        " "1)" enumeration style for consistency with the region above):
        syn match markdownListMarker "\s*[-*+]\%(\s\+\S\)\@=" contained
        syn match markdownOrderedListMarker "\s*\<\d\+[.)]\%(\s\+\S\)\@=" contained
    else
        " Restore the stock rules from syntax/markdown.vim:
        syn clear markdownCodeBlock markdownListMarker markdownOrderedListMarker
        syn region markdownCodeBlock start="^\n\( \{4,}\|\t\)" end="^\ze \{,3}\S.*$" keepend
        syn region markdownCodeBlock matchgroup=markdownCodeDelimiter start="^\s*\z(`\{3,\}\).*$" end="^\s*\z1\ze\s*$" keepend
        syn region markdownCodeBlock matchgroup=markdownCodeDelimiter start="^\s*\z(\~\{3,\}\).*$" end="^\s*\z1\ze\s*$" keepend
        syn match markdownListMarker "\%(\t\| \{0,4\}\)[-*+]\%(\s\+\S\)\@=" contained
        syn match markdownOrderedListMarker "\%(\t\| \{0,4}\)\<\d\+\.\%(\s\+\S\)\@=" contained
    endif
endfunction

function! MdCodeBlockFixArgs(ArgLead, CmdLine, CursorPos)
    return "on\noff\n"
endfunction

" Invoke to enable or disable the fix for Markdown code blocks:
"   :MdCodeBlockFix on          " Enable fix.
"   :MdCodeBlockFix off         " Disable fix.
command! -nargs=* -complete=custom,MdCodeBlockFixArgs
        \ MdCodeBlockFix call MdCodeBlockFix(<f-args>)
