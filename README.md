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

Install as a Mix archive from GitHub:

```bash
mix archive.install github pinetops/track_upstream
```

This makes the `mix track_upstream` command available globally from any directory.

To update to the latest version:

```bash
mix archive.install github pinetops/track_upstream --force
```

To uninstall:

```bash
mix archive.uninstall track_upstream
```

### Local Installation (Within a Project)

Alternatively, add to your project's dependencies in `mix.exs`:

```elixir
{:track_upstream, github: "pinetops/track_upstream"}
```

Then:

```bash
mix deps.get
mix track_upstream <args>
```

## Configuration

Create a `.track_upstream_config.md` file in your downstream project directory. This file should contain:

- Upstream and downstream project names and abbreviations
- Repository paths
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
**Repository Path:** .

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
mix track_upstream <upstream_start_rev> <upstream_end_rev> <downstream_rev> [options]
```

### Arguments

- `upstream_start_rev` - Upstream starting revision (e.g., v1.0.18, commit hash)
- `upstream_end_rev` - Upstream ending revision (e.g., v1.1.14, commit hash)
- `downstream_rev` - Downstream revision to compare (e.g., commit hash)

### Options

- `--upstream-dir <path>` - Path to upstream repository (overrides config file)

### Examples

```bash
# Full analysis with porting guide generation (using config file)
mix track_upstream v1.0.18 v1.1.14 5905fd1

# Specify upstream directory explicitly
mix track_upstream v1.0.18 v1.1.14 5905fd1 --upstream-dir ../upstream-repo

# Run from any directory if installed globally
cd /path/to/downstream/project
mix track_upstream v1.0.18 v1.1.14 5905fd1
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

# Build Mix archive
mix archive.build

# Install locally
mix archive.install
```

### Testing

```bash
# Format code
mix format

# Build and test
mix archive.build
mix archive.install

# Test the installed command
cd /path/to/test/project
mix track_upstream v1.0.0 v1.1.0 abc123
```

## License

Copyright (c) 2025 bucko

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
