# Track Upstream

A command-line tool for tracking and analyzing upstream changes between derivative projects, helping to identify and port changes systematically.

## Overview

Track Upstream uses OpenAI embeddings with cosine similarity for semantic code matching to help identify analogous files between upstream and downstream codebases. All embeddings and analysis results are cached locally to avoid redundant API calls.

### Purpose

This tool helps port changes from an upstream project to a downstream derivative project by:

1. **Identifying analogous implementations** - Finding which downstream files correspond to upstream files to implement analogous solutions for all changes between specified revisions

2. **Translating tests** - Identifying which tests added to the upstream project can and should be translated to the downstream project to maintain test coverage parity

3. **Generating porting guides** - Creating detailed documentation of transformation rules and upstream changes to guide the implementation of analogous features

The goal is to ensure downstream projects maintain functional parity with their upstream sources while adapting for their specific requirements.

## Installation

### Prerequisites

- Elixir 1.15 or later
- Erlang/OTP 25 or later
- Git
- An OpenAI API key

### Global Installation (Recommended)

Install as an escript to get a standalone executable:

```bash
# Install from GitHub
mix escript.install github pinetops/track_upstream

# Or build and install locally
git clone https://github.com/pinetops/track_upstream.git
cd track_upstream
mix do deps.get, escript.build, escript.install
```

**Important:** Make sure `~/.mix/escripts` is in your PATH:

```bash
# Add to your ~/.zshrc or ~/.bashrc
export PATH="$HOME/.mix/escripts:$PATH"
```

Then you can run it from anywhere:

```bash
track_upstream <args>
```

### Managing the Installation

To update to the latest version:

```bash
mix escript.install github pinetops/track_upstream --force
```

To uninstall:

```bash
mix escript.uninstall track_upstream
```

To list installed escripts:

```bash
ls ~/.mix/escripts
```

## Configuration

Create a `.track_upstream_config.md` file in your downstream project directory. This file should contain:

- Upstream and downstream project names and abbreviations
- Porting constraints specific to your project

### Configuration File Format

The configuration file uses markdown format with specific sections:

```markdown
# Track Upstream Configuration

## Upstream Project

**Name:** [Upstream Project Name]
**Abbreviation:** [abbrev]

## Downstream Project

**Name:** [Your Project Name]
**Abbreviation:** [abbrev]

## Porting Constraints

IMPORTANT CONSTRAINTS when porting from upstream to downstream:

1. **[Constraint Category]:**
   - Description of constraint
   - Specific rules or considerations

2. **[Another Category]:**
   - More constraints...
```

**Example:** Create this file in your downstream project root directory before running the tool.

## Usage

### Basic Syntax

```bash
track_upstream <upstream_start_rev> <upstream_end_rev> <downstream_rev> --upstream-dir <path>
```

### Arguments

- `upstream_start_rev` - Upstream starting revision (e.g., v2.0.0, commit hash, branch name)
- `upstream_end_rev` - Upstream ending revision (e.g., main, v2.1.0, commit hash)
- `downstream_rev` - Downstream revision to compare against (e.g., main, commit hash)
- `--upstream-dir <path>` - Path to upstream repository

### Typical Workflow

```bash
# 1. Navigate to your downstream project
cd /path/to/your/downstream-project

# 2. Create a new branch for the porting work
git checkout -b port-upstream-changes

# 3. Run track_upstream to analyze changes
# Compare upstream's v2.0.0 tag to current main, against your current main
track_upstream v2.0.0 main main --upstream-dir ../upstream-repo

# This generates:
# - UPSTREAM_PORTING_GUIDE.md (your main reference)
# - translation_analyses/ directory (detailed file-by-file analysis)
```

### Using the Generated Guide

After running the tool, you'll have an `UPSTREAM_PORTING_GUIDE.md` file. This guide is designed to work with AI coding assistants:

**With Claude Code or similar tools:**

1. Open the generated `UPSTREAM_PORTING_GUIDE.md` in your editor
2. Tell your AI assistant: "Read the UPSTREAM_PORTING_GUIDE.md file and port all the upstream changes to our codebase. Work through each file pair systematically, applying the documented transformation rules to the upstream deltas. Complete the entire porting process."
3. The AI will use the transformation rules and upstream deltas to guide implementation
4. Review and test the changes as the AI completes each file

The guide includes:
- **File-global transformation rules** - How to adapt upstream patterns to your downstream code
- **Upstream deltas** - What changed upstream that needs porting
- **Context** - Why changes were made and how they fit together

### Additional Examples

```bash
# Compare specific commit range
track_upstream abc123 def456 main --upstream-dir ../upstream-repo

# Use absolute path for upstream directory
track_upstream v2.0.0 main main --upstream-dir /path/to/upstream-repo

# Compare against a specific downstream commit
track_upstream v2.0.0 main 5905fd1 --upstream-dir ../upstream-repo
```

## Requirements

### Environment Setup

1. **OPENAI_API_KEY environment variable must be set:**
   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

2. **Configuration file:**
   You must create a `.track_upstream_config.md` file in your downstream repository. This file specifies:
   - Upstream project name and abbreviation
   - Downstream project name and abbreviation
   - Porting constraints specific to your project relationship

   See the Configuration section above for the file format.

3. **Run from downstream repository:**
   The tool should be run from within the downstream repository directory where you want to apply the changes.

## Output

The tool generates:

- **Matched file pairs** (existing upstream/downstream files)
- **Newly added upstream files** categorized by relevance
- **Summary statistics**
- **Individual file pair analyses** in `translation_analyses/` directory
- **Global porting guide** in `UPSTREAM_PORTING_GUIDE.md`

## How It Works

1. **File Matching**: Uses OpenAI embeddings to calculate semantic similarity between upstream and downstream files

2. **LLM Verification**: For high-similarity matches (>70%), uses GPT to verify if files are true translations

3. **Change Detection**: Identifies which files have changed between upstream versions

4. **Analysis**: For changed files, generates detailed analysis including:
   - Baseline transformation rules (how upstream was adapted to downstream)
   - Upstream delta (what changed upstream that needs porting)
   - Porting guidance

5. **Guide Generation**: Aggregates all analyses into a comprehensive porting guide

## Cache Management

The tool caches:
- OpenAI embeddings (`.track_changes_cache/embeddings/`)
- Similarity calculations (`.track_changes_cache/similarity/`)
- LLM verifications (`.track_changes_cache/verification/`)
- Git file contents (`.track_changes_cache/git_content/`)
- Module extractions (`.track_changes_cache/modules/`)

To clear the cache and start fresh:

```bash
rm -rf .track_changes_cache/
```

## Development

### Project Structure

```
track_upstream/
├── lib/
│   ├── track_upstream.ex              # Main module (moduledoc only)
│   ├── track_upstream/
│   │   ├── analysis.ex                # Analysis orchestration
│   │   ├── cache.ex                   # Generic caching utilities
│   │   ├── cli.ex                     # CLI interface and orchestration
│   │   ├── config.ex                  # Configuration management
│   │   ├── file_matcher.ex            # File matching logic
│   │   ├── file_pair_analyzer.ex      # File pair diff generation
│   │   ├── git.ex                     # Git operations
│   │   ├── guide_builder.ex           # Global translation guide builder
│   │   └── openai/
│   │       ├── chat.ex                # OpenAI chat completions (via LangChain)
│   │       └── embeddings.ex          # OpenAI embeddings (direct API)
│   └── mix/
│       └── tasks/
│           └── track_upstream.ex      # Mix task implementation
├── mix.exs                            # Mix project configuration
├── .formatter.exs                     # Code formatting configuration
├── .gitignore                         # Git ignore rules
└── README.md                          # This file
```

### Building from Source

```bash
# Get dependencies
mix deps.get

# Compile
mix compile

# Build escript
mix escript.build

# Install locally
mix escript.install
```

### Testing

```bash
# Format code
mix format

# Build and test
mix escript.build
mix escript.install

# Test the installed command
cd /path/to/test/project
track_upstream v2.0.0 main main --upstream-dir ../upstream-repo
```

## License

Copyright (c) 2025 Thomas Clarke <tom@u2i.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
