// CQL2 expression sub-language.
//
// The vocabulary of the OGC Common Query Language (CQL2, OGC 21-065r2) as
// embedded in CartoSym-CSS selectors: literals, identifiers, operators,
// function calls and array literals. This grammar is imported by
// `CartoSymCSSGrammar.g4`, which owns the left-recursive `expression`
// combinator and adds the CartoSym-specific alternatives (instances,
// `@variables`, coordinate tuples).
//
// Tokens resolve from the composite grammar's `tokenVocab=CartoSymCSSLexer`;
// this delegate deliberately declares no `options` block.

parser grammar CQL2Expression;

///////////////////////////////
// Literals & identifiers

idOrConstant:
     IDENTIFIER
   | expConstant
   | TRUE
   | FALSE
   | NULL;

expConstant: NUMERIC_LITERAL UNIT? | HEX_LITERAL;

expString: CHARACTER_LITERAL;

///////////////////////////////
// Arrays

expArray:
     LSBR arrayElements? RSBR
   | LPAR arrayElements? RPAR;

arrayElements:
     expression
   | arrayElements COMMA expression ;

///////////////////////////////
// Function calls

expCall: IDENTIFIER LPAR arguments RPAR ;

arguments:
   expression
   | arguments COMMA expression;

///////////////////////////////
// Operators

binaryLogicalOperator: AND | OR ;

unaryLogicalOperator: NOT ;

unaryArithmeticOperator: PLUS | MINUS;

arithmeticOperatorExp:
   POW;

arithmeticOperatorMul:
     MUL
   | DIV
   | IDIV
   | MOD;

arithmeticOperatorAdd:
     MINUS
   | PLUS
;

relationalOperator:
     EQ
   | LT
   | LTEQ
   | GT
   | GTEQ
   | IN
   | NOT IN
   | IS
   | IS NOT
   | LIKE
   | NOT LIKE;

betweenOperator:
     BETWEEN
   | NOT BETWEEN;
