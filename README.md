# CartoSym-CSS Grammar

ANTLR 4 grammar for the OGC CartoSym-CSS encoding, part of the [OGC Cartographic Symbology](https://github.com/opengeospatial/cartographic-symbology) standard.

## About

This repository provides an ANTLR grammar to parse CartoSym-CSS, a CSS-inspired syntax for cartographic styling. CartoSym-CSS offers a human-readable alternative to CartoSym-JSON for defining map styles.

## Files

- **`CartoSymCSSGrammar.g4`** - Parser grammar defining CartoSym-CSS syntax rules
- **`CartoSymCSSLexer.g4`** - Lexer grammar defining tokens and tokenization

## Usage

Generate parser/lexer classes with ANTLR 4:

```bash
antlr4 CartoSymCSSLexer.g4
antlr4 CartoSymCSSGrammar.g4
```

## Reference

Implements the CartoSym-CSS language as defined in:
- [OGC Cartographic Symbology - Part 1](https://docs.ogc.org/DRAFTS/18-067r4.html)
- [Official OGC Repository](https://github.com/opengeospatial/cartographic-symbology)
