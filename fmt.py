import sys
import platform

def tokenize(p_line):
    """Tokenize a line of nasm code."""
    tokens = []
    token_begin_idx = 0
    litc = '' # Character that starts a literal.
    for i in range(len(p_line)):
        c = p_line[i]
        if len(litc): # During reading literal.
            if litc == c:
                litc = ''
            continue
        else:
            if c in '\'\"': # Start reading literal.
                new_tok = p_line[token_begin_idx:i]
                if len(new_tok):
                    tokens.append(new_tok)
                token_begin_idx = i
                litc = c
                continue
            elif c in ' \t': # Whitespace.
                new_tok = p_line[token_begin_idx:i]
                if len(new_tok):
                    tokens.append(p_line[token_begin_idx:i])
                token_begin_idx = i + 1
                continue
            elif c in ';:': # Important symbols.
                new_tok = p_line[token_begin_idx:i]
                if len(new_tok):
                    tokens.append(p_line[token_begin_idx:i])
                tokens.append(c)
                token_begin_idx = i + 1
                continue
    else:
        if token_begin_idx != len(p_line):
            tokens.append(p_line[token_begin_idx:])
    return tokens

def format(p_code):
    """Format nasm code."""
    NEWLINE = "\r\n" if platform.system() == "Windows" else "\n"
    lines = p_code.split(NEWLINE)
    def format_line(p_line):
        """Format a line of nasm code."""
        def is_line_label(p_tokens):
            last_token_idx = 0
            try: last_token_idx = p_tokens.index(';')
            except ValueError: pass
            last_token_idx -= 1
            return p_tokens[last_token_idx] == ':'
        tokens = tokenize(p_line)
        if not len(tokens): return ""
        new_line = ' '.join(tokens)
        if (
            not is_line_label(tokens) and # A label.
            not tokens[0][0] == "%" and # A directive.
            not tokens[0][0] == ";" and # A comment.
            not tokens[0][0] == "["
        ):
            new_line = '\t' + new_line
        return new_line
    new_lines = []
    for line in lines:
        new_line = format_line(line)
        if len(new_line):
            new_lines.append(new_line)
    return '\n'.join(new_lines)

def main():
    FILEPATHS = sys.argv[1:]
    if not len(FILEPATHS):
        print(f"usage: python {sys.argv[0]} {{filepaths...}}", file=sys.stderr)
    for filepath in FILEPATHS:
        formatted = ""
        with open(filepath, "r") as file:
            formatted = format(file.read())
        with open(filepath, "w") as file:
            file.write(formatted)
    return 0

if __name__ == "__main__":
    exit(main())
