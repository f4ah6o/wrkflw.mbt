///|
/// Token types for expression parsing
pub enum Token {
  // Identifiers and literals
  Identifier(String)
  StringLiteral(String)
  Number(Int)

  // Operators
  EqualEqual
  NotEqual
  And
  Or
  Not
  Less
  Greater
  LessEqual
  GreaterEqual

  // Delimiters
  LParen
  RParen
  Dot
  Comma
  LBracket
  RBracket

  // EOF
  EOF
} derive(Show)

///|
/// Get the string representation of a token
pub fn Token::to_string(self : Token) -> String {
  match self {
    Identifier(s) => "Identifier(" + s + ")"
    StringLiteral(s) => "StringLiteral(\"" + s + "\")"
    Number(n) => "Number(" + int_to_string(n) + ")"
    EqualEqual => "=="
    NotEqual => "!="
    And => "&&"
    Or => "||"
    Not => "!"
    Less => "<"
    Greater => ">"
    LessEqual => "<="
    GreaterEqual => ">="
    LParen => "("
    RParen => ")"
    Dot => "."
    Comma => ","
    LBracket => "["
    RBracket => "]"
    EOF => "<EOF>"
  }
}

///|
/// Lexer state
pub struct Lexer {
  source : String
  pos : Int
  length : Int
}

///|
/// Create a new lexer
pub fn Lexer::new(source : String) -> Lexer {
  let len = source.length()
  { source, pos: 0, length: len }
}

///|
/// Get current character
fn Lexer::current_char(self : Lexer) -> Char {
  if self.pos < self.length {
    self.source[self.pos].to_int().unsafe_to_char()
  } else {
    '\u0000'
  }
}

///|
/// Peek at the next character
fn Lexer::peek_char(self : Lexer) -> Char {
  let next_pos = self.pos + 1
  if next_pos < self.length {
    self.source[next_pos].to_int().unsafe_to_char()
  } else {
    '\u0000'
  }
}

///|
/// Advance to next character
fn Lexer::advance(self : Lexer) -> Lexer {
  { source: self.source, pos: self.pos + 1, length: self.length }
}

///|
/// Skip whitespace
fn Lexer::skip_whitespace(self : Lexer) -> Lexer {
  let mut pos = self.pos
  while pos < self.length {
    let c = self.source[pos].to_int().unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      pos = pos + 1
    } else {
      break
    }
  }
  { source: self.source, pos, length: self.length }
}

///|
/// Check if character is identifier start
fn is_identifier_start(c : Char) -> Bool {
  ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z') || c == '_'
}

///|
/// Check if character is identifier continuation
fn is_identifier_char(c : Char) -> Bool {
  is_identifier_start(c) || ('0' <= c && c <= '9') || c == '-' || c == '.'
}

///|
/// Check if character is digit
fn is_digit(c : Char) -> Bool {
  '0' <= c && c <= '9'
}

///|
/// Lex an identifier or keyword
fn Lexer::lex_identifier(self : Lexer) -> (Token, Lexer) {
  let start = self.pos
  let mut lexer = self

  while lexer.pos < lexer.length && is_identifier_char(lexer.source[lexer.pos].to_int().unsafe_to_char()) {
    lexer = lexer.advance()
  }

  let text = self.source.substring(start~, end=lexer.pos)
  (Identifier(text), lexer)
}

///|
/// Lex a string literal
fn Lexer::lex_string(self : Lexer) -> (Token, Lexer) {
  let quote = self.source[self.pos].to_int().unsafe_to_char()
  let mut lexer = self.advance()
  let start = lexer.pos
  let mut escaped = false

  while lexer.pos < lexer.length && (escaped || lexer.source[lexer.pos].to_int().unsafe_to_char() != quote) {
    if !escaped && lexer.source[lexer.pos].to_int().unsafe_to_char() == '\\' {
      escaped = true
    } else {
      escaped = false
    }
    lexer = lexer.advance()
  }

  let text = self.source.substring(start~, end=lexer.pos)
  // Skip closing quote
  lexer = lexer.advance()
  (StringLiteral(text), lexer)
}

///|
/// Lex a number
fn Lexer::lex_number(self : Lexer) -> (Token, Lexer) {
  let start = self.pos
  let mut lexer = self

  while lexer.pos < lexer.length {
    let c = lexer.source[lexer.pos].to_int().unsafe_to_char()
    if is_digit(c) {
      lexer = lexer.advance()
    } else {
      break
    }
  }

  let text = self.source.substring(start~, end=lexer.pos)
  // Parse the number (simplified - assumes valid input)
  let mut value = 0
  let mut i = 0
  while i < text.length() {
    let c = text[i].to_int().unsafe_to_char()
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  (Number(value), lexer)
}

///|
/// Get the next token
pub fn Lexer::next_token(self : Lexer) -> (Token, Lexer) {
  let mut lexer = self.skip_whitespace()

  let c = lexer.current_char()

  if lexer.pos >= lexer.length {
    (EOF, lexer)
  } else if c == '(' {
    (LParen, lexer.advance())
  } else if c == ')' {
    (RParen, lexer.advance())
  } else if c == '.' {
    (Dot, lexer.advance())
  } else if c == ',' {
    (Comma, lexer.advance())
  } else if c == '[' {
    (LBracket, lexer.advance())
  } else if c == ']' {
    (RBracket, lexer.advance())
  } else if c == '!' {
    let next = lexer.peek_char()
    if next == '=' {
      (NotEqual, lexer.advance().advance())
    } else {
      (Not, lexer.advance())
    }
  } else if c == '=' {
    let next = lexer.peek_char()
    if next == '=' {
      (EqualEqual, lexer.advance().advance())
    } else {
      // Single '=' is not supported
      (EOF, lexer)
    }
  } else if c == '&' {
    let next = lexer.peek_char()
    if next == '&' {
      (And, lexer.advance().advance())
    } else {
      (EOF, lexer)
    }
  } else if c == '|' {
    let next = lexer.peek_char()
    if next == '|' {
      (Or, lexer.advance().advance())
    } else {
      (EOF, lexer)
    }
  } else if c == '<' {
    let next = lexer.peek_char()
    if next == '=' {
      (LessEqual, lexer.advance().advance())
    } else {
      (Less, lexer.advance())
    }
  } else if c == '>' {
    let next = lexer.peek_char()
    if next == '=' {
      (GreaterEqual, lexer.advance().advance())
    } else {
      (Greater, lexer.advance())
    }
  } else if c == '"' || c == '\'' {
    lexer.lex_string()
  } else if is_digit(c) {
    lexer.lex_number()
  } else if is_identifier_start(c) {
    lexer.lex_identifier()
  } else {
    // Unknown character
    (EOF, lexer.advance())
  }
}

///|
/// Tokenize an entire expression
pub fn tokenize(source : String) -> Array[Token] {
  let mut lexer = Lexer::new(source)
  let mut tokens = []
  let mut done = false

  while !done {
    let (token, new_lexer) = lexer.next_token()
    tokens = tokens + [token]
    lexer = new_lexer

    match token {
      EOF => done = true
      _ => ()
    }
  }

  tokens
}

///|
/// Convert int to string (simple implementation)
pub fn int_to_string(n : Int) -> String {
  if n == 0 {
    return "0"
  }

  let mut num = n
  let mut is_negative = false

  if n < 0 {
    is_negative = true
    num = -n
  }

  let mut chars : Array[Char] = []
  while num > 0 {
    let digit = num % 10
    let c = ('0'.to_int() + digit).unsafe_to_char()
    chars = [c] + chars
    num = num / 10
  }

  if is_negative {
    chars = ['-'] + chars
  }

  let mut result = ""
  let mut i = 0
  while i < chars.length() {
    result = result + chars[i].to_string()
    i = i + 1
  }
  result
}
