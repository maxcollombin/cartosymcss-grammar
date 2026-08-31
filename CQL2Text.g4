// Standalone CQL2-Text grammar (OGC 21-065r2, Common Query Language 2).
//
// This is a *separate* grammar from `CQL2Expression.g4` / the composite
// `CartoSymCSSGrammar.g4`: it does not share `CartoSymCSSLexer.g4`'s token
// vocabulary and is not imported by it. Reason: CQL2-Text keywords
// (AND/OR/NOT/LIKE/BETWEEN/IN/IS/NULL, S_*/T_*/A_* predicate names,
// CASEI/ACCENTI, DATE/TIMESTAMP/INTERVAL, the WKT geometry tags) are
// case-insensitive per the OGC standard, while `CartoSymCSSLexer.g4`'s
// keywords are lowercase-only literals shared with the case-sensitive
// CartoSym-CSS selector language. The two cannot be merged without either
// breaking CSCSS case-sensitivity or CQL2-Text case-insensitivity, so
// this is its own standalone (combined lexer+parser) grammar, used only
// by `cql2/from_text.py`'s standalone-CQL2-Text entry point — not by
// anything that parses a `.cscss` file. Its own lexer+parser are
// generated separately from `CartoSymCSSLexer.g4`/`CartoSymCSSGrammar.g4`
// above, since it shares no tokens with them.
//
// Source of truth: the OGC-published ABNF grammar
// (`cql2/standard/schema/cql2.bnf` in `opengeospatial/ogcapi-features`).
// `developmentseed/cql2-rs`'s `src/cql2.pest` (a PEG port of the same
// ABNF) is used only as a secondary cross-check / engineering-pattern
// reference, per the project's own decision (ABNF is normative; a PEG
// grammar's ordered-choice resolution strategy does not always translate
// literally into ANTLR's ALL(*) prediction, so its *rules* are not
// ported verbatim — only checked against for coverage).
//
// Deliberate departures from a literal ABNF transcription (each noted
// again at the rule it affects):
//
// 1. The ABNF's `scalarExpression`/`arithmeticExpression`/`numericExpression`/
//    `isNullOperand`/`argument`/`arrayElement` productions are mutually-
//    recursive unions that differ only in *which* subset of {character,
//    numeric, temporal, spatial, boolean, array, propertyName, function}
//    literals they admit. Transcribed literally into ANTLR this produces
//    a hugely ambiguous grammar (and reportedly does for `cql2-rs`'s own
//    author, per that file's comments). Instead there is a single `atom`
//    rule (any literal/propertyName/function/array) feeding one
//    arithmetic-precedence chain (`arithmeticExpr`), and the ABNF's type
//    restrictions (e.g. "BETWEEN operands SHALL be numeric") are left
//    for the tree-walker/model layer to enforce — the same "syntax
//    admits more than is semantically valid, validated downstream"
//    architecture this project already uses for `S_RELATE`'s DE-9IM
//    pattern (`models/de9im.py`).
// 2. `function`'s `"(" {argumentList} ")"` (an ABNF `{...}` = zero-or-
//    more *repetitions* of the already comma-separated `argumentList`)
//    is read as the obvious intent — one optional `argumentList` — not
//    literally (which would make the argument-comma-list itself
//    repeatable, ambiguously). `cql2-rs`'s `FunctionArgs` reads it the
//    same way.
// 3. A parenthesized single value, e.g. `(5)`, is ambiguous in the ABNF
//    itself between "a grouped expression" (`arithmeticFactor`'s
//    `"(" arithmeticExpression ")"`) and "a one-element array" (`array`'s
//    `"(" arrayElement ")"` — the ABNF's outer `[ {...} ]` around the
//    repeated-comma part is optional, so one bare element already
//    satisfies it). Resolved the same way `cql2-rs` resolves it
//    (`AtomicExpr` tries `ExpressionInParentheses` before `Array`):
//    grouping wins: `arrayExpr` requires >= 2 comma-separated elements
//    (or the empty `()`).
// 4. `characterClause`'s ABNF text (`"CASEI" "(" characterExpression ")"`)
//    wraps `characterExpression` — which itself admits `propertyName` and
//    `function`, not just another `characterClause`/literal. A literal
//    transcription of just `characterClause | characterClause` would
//    reject `ACCENTI(etat_vol)` (property operand), which is valid text
//    per the OGC-published Annex B examples (`clause7_05.txt` /
//    `example27.txt` in the official examples corpus — confirms this is
//    real usage, not an ABNF edge case to ignore).
// 5. `NEQ` accepts both `<>` (the only form the ABNF defines) and `!=`
//    (not in the ABNF, but accepted by `cql2-rs` and common in the wild).
//    Purely additive/lenient — never required, never emitted by our own
//    writer — flagged here since it is a real, if small, divergence from
//    the ABNF text.
//
// No `HEX_LITERAL` token: the OGC standard defines no hexadecimal numeric
// literal syntax anywhere (`numericLiteral` is decimal/scientific only) —
// verified against both the ABNF and the CQL2 clause of OGC 21-065r2.
// (`#`-prefixed hex is a `CartoSymCSSLexer.g4` token for CSS colors,
// unrelated to CQL2-Text numbers.)

grammar CQL2Text;

///////////////////////////////////////////////////////////////////////
// Parser: boolean layer (ABNF booleanExpression / booleanTerm /
// booleanFactor / booleanPrimary / predicate)
///////////////////////////////////////////////////////////////////////

cql2Text: booleanExpression EOF;

booleanExpression: booleanTerm (OR booleanTerm)*;

booleanTerm: booleanFactor (AND booleanFactor)*;

booleanFactor: NOT* primary;

// ABNF's `booleanPrimary` (function | predicate | booleanLiteral |
// "(" booleanExpression ")") and `predicate` (comparisonPredicate |
// spatialPredicate | temporalPredicate | arrayPredicate) collapse here.
// `operand predicateTail?` covers: a bare scalar/boolean-literal/
// function/property value (no tail — e.g. `swimming_pool = true`'s RHS,
// or a boolean-valued function call used standalone), and all four
// `comparisonPredicate` forms via `predicateTail`. `spatialPredicate`/
// `temporalPredicate`/`arrayPredicate` are self-contained
// `KEYWORD "(" operand "," operand ")"` shapes (their own function-style
// keyword tokens, never ambiguous with `operand`'s own `functionCall`
// since S_*/T_*/A_* names are dedicated keyword tokens, not IDENTIFIER).
//
// `operand` is tried before the explicit `"(" booleanExpression ")"`
// grouping: for a parenthesized *purely arithmetic* group, e.g. `(1+2)`,
// both alternatives can fully match (see divergence 3's sibling case);
// `operand` wins by being listed first — semantically equivalent either
// way, since it bottoms out at the same `atom` either path.
primary:
      spatialPredicate
    | temporalPredicate
    | arrayPredicate
    | operand predicateTail?
    | LPAR booleanExpression RPAR
    ;

predicateTail:
      comparisonOperator operand                                    # comparisonTail
    | NOT? LIKE characterClause                                      # likeTail
    | NOT? BETWEEN arithmeticExpr AND arithmeticExpr                 # betweenTail
    | NOT? IN LPAR inList RPAR                                       # inTail
    | IS NOT? NULL                                                   # isNullTail
    ;

comparisonOperator: EQ | NEQ | LTEQ | GTEQ | LT | GT;

inList: operand (COMMA operand)*;

///////////////////////////////////////////////////////////////////////
// Parser: spatial / temporal / array predicates
///////////////////////////////////////////////////////////////////////

spatialPredicate: spatialFunction LPAR operand COMMA operand RPAR;

spatialFunction:
     S_INTERSECTS | S_EQUALS | S_DISJOINT | S_TOUCHES
   | S_WITHIN | S_OVERLAPS | S_CROSSES | S_CONTAINS;

temporalPredicate: temporalFunction LPAR operand COMMA operand RPAR;

temporalFunction:
     T_AFTER | T_BEFORE | T_CONTAINS | T_DISJOINT | T_DURING | T_EQUALS
   | T_FINISHEDBY | T_FINISHES | T_INTERSECTS | T_MEETS | T_METBY
   | T_OVERLAPPEDBY | T_OVERLAPS | T_STARTEDBY | T_STARTS;

arrayPredicate: arrayFunction LPAR operand COMMA operand RPAR;

arrayFunction: A_EQUALS | A_CONTAINS | A_CONTAINEDBY | A_OVERLAPS;

///////////////////////////////////////////////////////////////////////
// Parser: arithmetic layer (ABNF arithmeticExpression / arithmeticTerm /
// powerTerm / arithmeticFactor / arithmeticOperand)
///////////////////////////////////////////////////////////////////////

// `operand` is the entry point used everywhere a scalar/typed value is
// expected (predicate operands, function/predicate arguments, array
// elements, IN-list elements) — see divergence 1.
operand: arithmeticExpr;

arithmeticExpr: arithmeticTerm ((PLUS | MINUS) arithmeticTerm)*;

arithmeticTerm: powerTerm ((MUL | SLASH | IDIV | MOD) powerTerm)*;

powerTerm: arithmeticFactor (POW arithmeticFactor)?;

arithmeticFactor:
      LPAR arithmeticExpr RPAR
    | MINUS? atom
    ;

atom:
      geometryLiteral
    | temporalInstant
    | characterClause
    | NUMERIC_LITERAL
    | booleanLiteral
    | propertyName
    | functionCall
    | arrayExpr
    ;

booleanLiteral: TRUE | FALSE;

propertyName: IDENTIFIER | QUOTED_IDENTIFIER;

functionCall: IDENTIFIER LPAR argumentList? RPAR;   // see divergence 2

argumentList: operand (COMMA operand)*;

// >= 2 elements, or empty; a single parenthesized value is a grouped
// expression, not a one-element array — see divergence 3.
arrayExpr: LPAR RPAR | LPAR operand (COMMA operand)+ RPAR;

// ABNF's `characterClause` / `patternExpression` are the same shape
// (CASEI/ACCENTI-wrapped-or-bare string) and are merged into one rule,
// used for both the LIKE pattern operand and any character-typed value.
// The CASEI/ACCENTI argument is `characterClauseArg`, not another bare
// `characterClause` — see divergence 4.
characterClause:
      CASEI LPAR characterClauseArg RPAR
    | ACCENTI LPAR characterClauseArg RPAR
    | STRING
    ;

characterClauseArg: characterClause | propertyName | functionCall;

///////////////////////////////////////////////////////////////////////
// Parser: geometric literals (WKT) + BBOX
///////////////////////////////////////////////////////////////////////

geometryLiteral:
      pointTaggedText
    | linestringTaggedText
    | polygonTaggedText
    | multipointTaggedText
    | multilinestringTaggedText
    | multipolygonTaggedText
    | geometryCollectionTaggedText
    | bboxTaggedText
    ;

// A mandatory whitespace-skipped gap separates the tag from a `Z`
// suffix (`POLYGON Z (...)`, per the official examples corpus) —
// without a gap `POLYGONZ` lexes as one IDENTIFIER, never as
// `POLYGON` + `ZSUFFIX` (ANTLR's lexer always takes the longest match).
pointTaggedText: POINT ZSUFFIX? pointText;
linestringTaggedText: LINESTRING ZSUFFIX? lineStringText;
polygonTaggedText: POLYGON ZSUFFIX? polygonText;
multipointTaggedText: MULTIPOINT ZSUFFIX? multiPointText;
multilinestringTaggedText: MULTILINESTRING ZSUFFIX? multiLineStringText;
multipolygonTaggedText: MULTIPOLYGON ZSUFFIX? multiPolygonText;
geometryCollectionTaggedText: GEOMETRYCOLLECTION ZSUFFIX? geometryCollectionText;

pointText: LPAR point RPAR;
point: signedNumber signedNumber signedNumber?;   // x y [z]

lineStringText: LPAR point (COMMA point)+ RPAR;

// ABNF requires >= 4 points written out longhand (closed ring: >= 3
// distinct vertices + closing point); ANTLR parser rules have no
// `{n,}` bounded-repetition operator, so this is the literal expansion.
linearRingText:
      LPAR RPAR
    | LPAR point COMMA point COMMA point COMMA point (COMMA point)* RPAR
    ;

polygonText: LPAR linearRingText (COMMA linearRingText)* RPAR;
multiPointText: LPAR pointText (COMMA pointText)* RPAR;
multiLineStringText: LPAR lineStringText (COMMA lineStringText)* RPAR;
multiPolygonText: LPAR polygonText (COMMA polygonText)* RPAR;
geometryCollectionText: LPAR geometryLiteral (COMMA geometryLiteral)* RPAR;

bboxTaggedText: BBOX bboxText;

// west, south, [minElev,] east, north, [, maxElev]
bboxText:
    LPAR signedNumber COMMA signedNumber COMMA
         (signedNumber COMMA)?
         signedNumber COMMA signedNumber
         (COMMA signedNumber)?
    RPAR;

signedNumber: MINUS? NUMERIC_LITERAL;

///////////////////////////////////////////////////////////////////////
// Parser: temporal instants (DATE / TIMESTAMP / INTERVAL)
///////////////////////////////////////////////////////////////////////

// `fullDate`/`utcTime` structure (and INTERVAL's `'..'` open-bound
// marker) are left as opaque `STRING` content here and validated
// downstream by the tree-walker/model, not by the grammar — the same
// "syntax admits more than is semantically valid" split already used
// for `S_RELATE`'s DE-9IM pattern (`models/de9im.py`); no dedicated
// date/timestamp lexer token.
temporalInstant: dateInstant | timestampInstant | intervalInstant;

dateInstant: DATE LPAR STRING RPAR;
timestampInstant: TIMESTAMP LPAR STRING RPAR;
intervalInstant: INTERVAL LPAR instantParameter COMMA instantParameter RPAR;

instantParameter: STRING | propertyName | functionCall;

///////////////////////////////////////////////////////////////////////
// Lexer
///////////////////////////////////////////////////////////////////////

// Case-insensitive keyword idiom: one fragment per letter, keyword
// tokens spelled out as fragment sequences. Standard ANTLR4 pattern for
// a case-insensitive keyword set (there is no in-grammar case-fold
// flag). No `!NameChar`-style lookahead guard is needed the way a PEG
// grammar (e.g. `cql2-rs`'s `NotFlag = @{ ^"not" ~ !NameChar }`) needs
// one: ANTLR's lexer always takes the *longest* match across all rules
// at a position, so `notes` always lexes as one IDENTIFIER (7 chars),
// never as the 3-char NOT keyword followed by a 4-char remainder.
fragment A:[aA]; fragment B:[bB]; fragment C:[cC]; fragment D:[dD];
fragment E:[eE]; fragment F:[fF]; fragment G:[gG]; fragment H:[hH];
fragment I:[iI]; fragment J:[jJ]; fragment K:[kK]; fragment L:[lL];
fragment M:[mM]; fragment N:[nN]; fragment O:[oO]; fragment P:[pP];
fragment Q:[qQ]; fragment R:[rR]; fragment S:[sS]; fragment T:[tT];
fragment U:[uU]; fragment V:[vV]; fragment W:[wW]; fragment X:[xX];
fragment Y:[yY]; fragment Z:[zZ];

AND: A N D;
OR: O R;
NOT: N O T;
LIKE: L I K E;
BETWEEN: B E T W E E N;
IN: I N;
IS: I S;
NULL: N U L L;
TRUE: T R U E;
FALSE: F A L S E;
CASEI: C A S E I;
ACCENTI: A C C E N T I;

S_INTERSECTS: S '_' I N T E R S E C T S;
S_EQUALS: S '_' E Q U A L S;
S_DISJOINT: S '_' D I S J O I N T;
S_TOUCHES: S '_' T O U C H E S;
S_WITHIN: S '_' W I T H I N;
S_OVERLAPS: S '_' O V E R L A P S;
S_CROSSES: S '_' C R O S S E S;
S_CONTAINS: S '_' C O N T A I N S;

T_AFTER: T '_' A F T E R;
T_BEFORE: T '_' B E F O R E;
T_CONTAINS: T '_' C O N T A I N S;
T_DISJOINT: T '_' D I S J O I N T;
T_DURING: T '_' D U R I N G;
T_EQUALS: T '_' E Q U A L S;
T_FINISHEDBY: T '_' F I N I S H E D B Y;
T_FINISHES: T '_' F I N I S H E S;
T_INTERSECTS: T '_' I N T E R S E C T S;
T_MEETS: T '_' M E E T S;
T_METBY: T '_' M E T B Y;
T_OVERLAPPEDBY: T '_' O V E R L A P P E D B Y;
T_OVERLAPS: T '_' O V E R L A P S;
T_STARTEDBY: T '_' S T A R T E D B Y;
T_STARTS: T '_' S T A R T S;

A_EQUALS: A '_' E Q U A L S;
A_CONTAINS: A '_' C O N T A I N S;
A_CONTAINEDBY: A '_' C O N T A I N E D B Y;
A_OVERLAPS: A '_' O V E R L A P S;

POINT: P O I N T;
LINESTRING: L I N E S T R I N G;
POLYGON: P O L Y G O N;
MULTIPOINT: M U L T I P O I N T;
MULTILINESTRING: M U L T I L I N E S T R I N G;
MULTIPOLYGON: M U L T I P O L Y G O N;
GEOMETRYCOLLECTION: G E O M E T R Y C O L L E C T I O N;
BBOX: B B O X;
ZSUFFIX: Z;

DATE: D A T E;
TIMESTAMP: T I M E S T A M P;
INTERVAL: I N T E R V A L;

IDIV: D I V;   // integer-division keyword operator (ABNF's `"div"`)

LPAR: '(';
RPAR: ')';
COMMA: ',';

EQ: '=';
NEQ: '<>' | '!=';           // see divergence 5
LTEQ: '<=';
GTEQ: '>=';
LT: '<';
GT: '>';

PLUS: '+';
MINUS: '-';
MUL: '*';
SLASH: '/';
MOD: '%';
POW: '^';

NUMERIC_LITERAL:
      DIGIT+ ('.' DIGIT*)? (EXP_MARK SIGN? DIGIT+)?
    | '.' DIGIT+ (EXP_MARK SIGN? DIGIT+)?
    ;
fragment DIGIT: [0-9];
fragment SIGN: [+-];
fragment EXP_MARK: E;   // ABNF only shows uppercase 'E'; accepted either
                         // case for consistency with the rest of this
                         // case-insensitive grammar (common practice,
                         // e.g. JSON numbers).

// `''` and `\'` both escape an embedded quote per the ABNF's
// `escapeQuote = "''" | "\\'"`.
STRING: '\'' (STR_CHAR)* '\'';
fragment STR_CHAR: '\'\'' | '\\\'' | ~['];

QUOTED_IDENTIFIER: DQUOTE ID_START ID_CONTINUE* DQUOTE;
fragment DQUOTE: '"';

IDENTIFIER: ID_START ID_CONTINUE*;
// A simplified stand-in for the ABNF's `identifierStart`/`identifierPart`
// (which spell out ~20 explicit Unicode block ranges, copied from the
// XML Names production) — `\p{L}` (Unicode Letter) covers the intent
// without hand-transcribing those ranges. `cql2-rs`'s own pest grammar
// makes the same simplification (`ALPHABETIC | NUMBER | UNDERSCORE |
// PERIOD | COLON`).
fragment ID_START: [\p{L}_:];
fragment ID_CONTINUE: [\p{L}\p{Nd}_:.];

WS: [ \t\r\n\f]+ -> skip;
