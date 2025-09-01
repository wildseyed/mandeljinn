#!/usr/bin/env python3
"""
Norns Text Formatter
A tool to format text for norns screen (128 pixels wide) using character width approximations.

Since we can't access the actual norns text_extents() function from Python, this uses
empirically measured character widths for the default norns font (font face 1).

Usage:
    python norns_text_formatter.py "Your text here"
"""

import sys
import argparse

# Character width approximations for norns default font (font face 1)
# These are estimated pixel widths based on common proportional font characteristics
CHAR_WIDTHS = {
    # Narrow characters
    'i': 2, 'j': 2, 'l': 2, 't': 3, 'f': 3, 'r': 3, 'I': 2,
    
    # Punctuation and symbols
    ' ': 3, '.': 2, ',': 2, ':': 2, ';': 2, '!': 2, '|': 2, '\'': 2,
    '(': 3, ')': 3, '[': 3, ']': 3, '{': 3, '}': 3, '/': 3, '\\': 3,
    '-': 3, '_': 4, '=': 4, '+': 4, '~': 4, '`': 2, '"': 3,
    
    # Numbers
    '0': 5, '1': 3, '2': 5, '3': 5, '4': 5, '5': 5, '6': 5, '7': 5, '8': 5, '9': 5,
    
    # Regular lowercase
    'a': 5, 'b': 5, 'c': 4, 'd': 5, 'e': 5, 'g': 5, 'h': 5, 'k': 4, 'n': 5,
    'o': 5, 'p': 5, 'q': 5, 's': 4, 'u': 5, 'v': 4, 'x': 4, 'y': 4, 'z': 4,
    
    # Wide lowercase
    'm': 7, 'w': 7,
    
    # Regular uppercase
    'A': 6, 'B': 6, 'C': 6, 'D': 6, 'E': 5, 'F': 5, 'G': 6, 'H': 6, 'J': 4,
    'K': 6, 'L': 5, 'N': 6, 'O': 6, 'P': 5, 'Q': 6, 'R': 6, 'S': 6, 'T': 5,
    'U': 6, 'V': 6, 'X': 6, 'Y': 6, 'Z': 5,
    
    # Wide uppercase  
    'M': 8, 'W': 9,
}

# Default width for characters not in the table
DEFAULT_CHAR_WIDTH = 5

def get_char_width(char):
    """Get the estimated pixel width of a character."""
    return CHAR_WIDTHS.get(char, DEFAULT_CHAR_WIDTH)

def measure_text_width(text):
    """Calculate the estimated pixel width of a text string."""
    return sum(get_char_width(char) for char in text)

def wrap_text_for_norns(text, max_width=125, comment_prefix="-- "):
    """
    Wrap text to fit within norns screen width (128 pixels).
    
    Args:
        text: The text to wrap
        max_width: Maximum pixel width per line (default 125 to leave margin)
        comment_prefix: Prefix to add to each line (default "-- " for Lua comments)
    
    Returns:
        List of formatted lines
    """
    words = text.split()
    lines = []
    current_line = ""
    
    for word in words:
        # Calculate width if we add this word
        test_line = current_line + (" " if current_line else "") + word
        test_width = measure_text_width(comment_prefix + test_line)
        
        if test_width <= max_width:
            # Word fits, add it to current line
            current_line = test_line
        else:
            # Word doesn't fit, start new line
            if current_line:
                lines.append(comment_prefix + current_line)
            current_line = word
            
            # Check if single word is too long
            if measure_text_width(comment_prefix + word) > max_width:
                # Word itself is too long, need to break it
                # For now, just add it and let it overflow (could implement char-level breaking)
                lines.append(comment_prefix + word + " [OVERFLOW]")
                current_line = ""
    
    # Add the last line
    if current_line:
        lines.append(comment_prefix + current_line)
    
    return lines

def format_intro_text():
    """Format the Mandeljinn intro text for norns."""
    intro_paragraphs = [
        "Mandeljinn by Wildseyed vibin' with Claude",
        "",
        "Deep in the mathematical realm where infinite complexity emerges from simple rules, the Mandeljinn dwells. Ancient folklore speaks of genies trapped in lamps, but this Jinn inhabits the fractal landscape itself - a spirit of pure mathematics that transforms the eternal dance of complex numbers into living sound and vision.",
        "",
        "As you navigate these infinite shores, the Mandeljinn whispers the secret songs hidden within each point of the fractal plane. Every zoom reveals new mysteries, every orbit traces melodies that have waited eons to be heard. This is where mathematics becomes music, where iteration becomes rhythm, where chaos becomes art.",
        "",
        "CONTROLS:",
        "K1: Toggle menu / back",
        "K2: Add current location to sequence",
        "K3: Delete last sequence entry",
        "E1: Pan left/right (hold K2: zoom out/in)",
        "E2: Pan up/down (hold K2: change fractal)",
        "E3: Zoom in/out (hold K3: palette cycling)",
        "",
        "HOLD COMBINATIONS:",
        "K2 + E1: Zoom out/in",
        "K2 + E2: Change fractal type",
        "K3 + E3: Cycle color palette",
        "K2 + K3 (long press): Reset view to default",
        "",
        "https://github.com/wildseyed/mandeljinn"
    ]
    
    all_lines = []
    for paragraph in intro_paragraphs:
        if paragraph == "":
            all_lines.append("--")
        elif paragraph == "CONTROLS:" or paragraph == "HOLD COMBINATIONS:":
            # Section headers - don't wrap
            all_lines.append("-- " + paragraph)
        elif paragraph.startswith("http"):
            # URL - don't wrap
            all_lines.append("-- " + paragraph)
        else:
            # All other text including controls - wrap it
            wrapped = wrap_text_for_norns(paragraph)
            all_lines.extend(wrapped)
    
    return all_lines

def main():
    parser = argparse.ArgumentParser(description='Format text for norns screen')
    parser.add_argument('text', nargs='?', help='Text to format (if not provided, formats the Mandeljinn intro)')
    parser.add_argument('--width', type=int, default=125, help='Maximum pixel width per line (default: 125)')
    parser.add_argument('--no-comments', action='store_true', help='Don\'t add Lua comment prefix')
    
    args = parser.parse_args()
    
    if args.text:
        # Format user-provided text
        prefix = "" if args.no_comments else "-- "
        lines = wrap_text_for_norns(args.text, args.width, prefix)
        for line in lines:
            print(line)
    else:
        # Format the Mandeljinn intro text
        lines = format_intro_text()
        for line in lines:
            print(line)
        
        print("\n" + "="*50)
        print("Formatted for norns (128px width)")
        print("Copy the above lines into your Lua file header")

if __name__ == "__main__":
    main()
