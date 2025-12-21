import Link from "next/link";
import { Terminal } from "@/components/Terminal";

const demoOutput = `\x1b[36m$\x1b[0m ucharm run deploy.py

\x1b[1;34m╭─ Release ─────────────────────────────╮\x1b[0m
\x1b[1;34m│\x1b[0m Deploying build...                    \x1b[1;34m│\x1b[0m
\x1b[1;34m╰───────────────────────────────────────╯\x1b[0m

\x1b[1;32m✓\x1b[0m Built commit a1b2c3d

\x1b[90m┌───────────┬───────┬──────┐\x1b[0m
\x1b[90m│\x1b[0m\x1b[1m Artifact  \x1b[0m\x1b[90m│\x1b[0m\x1b[1m Size  \x1b[0m\x1b[90m│\x1b[0m\x1b[1m Time \x1b[0m\x1b[90m│\x1b[0m
\x1b[90m├───────────┼───────┼──────┤\x1b[0m
\x1b[90m│\x1b[0m app-linux \x1b[90m│\x1b[0m \x1b[32m900KB\x1b[0m \x1b[90m│\x1b[0m \x1b[33m6ms\x1b[0m  \x1b[90m│\x1b[0m
\x1b[90m│\x1b[0m app-macos \x1b[90m│\x1b[0m \x1b[32m910KB\x1b[0m \x1b[90m│\x1b[0m \x1b[33m7ms\x1b[0m  \x1b[90m│\x1b[0m
\x1b[90m└───────────┴───────┴──────┘\x1b[0m

\x1b[1;32m✓\x1b[0m Upload complete`;

const interactiveDemo = `\x1b[36m$\x1b[0m ucharm run setup.py

\x1b[90m───────────────────\x1b[0m Project Setup \x1b[90m───────────────────\x1b[0m

\x1b[1;33m?\x1b[0m Project name: \x1b[36mfastship\x1b[0m
\x1b[1;33m?\x1b[0m Select features:
  \x1b[32m◉\x1b[0m Logging
  \x1b[32m◉\x1b[0m HTTP
  \x1b[90m○\x1b[0m Config
\x1b[1;33m?\x1b[0m Create project now? \x1b[90m(Y/n)\x1b[0m \x1b[32my\x1b[0m

\x1b[1;32m✓\x1b[0m Created fastship with 2 features`;

const codeExample = `from ucharm import box, table, success, select

# Beautiful boxes
box("Deploying build...", title="Release", border_color="cyan")

# Interactive prompts
choice = select("Pick environment:", ["dev", "staging", "prod"])

# Formatted tables
table([
    ["Artifact", "Size", "Time"],
    ["app-linux", "900KB", "6ms"],
], headers=True)

success(f"Deployed to {choice}!")`;

function FeatureCard({
  icon,
  title,
  description,
}: {
  icon: string;
  title: string;
  description: string;
}) {
  return (
    <div className="p-6 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900/50">
      <div className="text-3xl mb-3">{icon}</div>
      <h3 className="text-lg font-semibold mb-2">{title}</h3>
      <p className="text-gray-600 dark:text-gray-400 text-sm">{description}</p>
    </div>
  );
}

export default function HomePage() {
  return (
    <div className="flex flex-col">
      {/* Hero Section */}
      <section className="py-20 px-6 text-center">
        <div className="max-w-4xl mx-auto">
          <h1 className="text-5xl md:text-6xl font-bold mb-6 tracking-tight">
            Beautiful CLI apps.{" "}
            <span className="bg-gradient-to-r from-cyan-500 to-blue-500 bg-clip-text text-transparent">
              Tiny binaries.
            </span>
          </h1>
          <p className="text-xl text-gray-600 dark:text-gray-400 mb-8 max-w-2xl mx-auto">
            Build stunning command-line applications with Python syntax. Ship
            them as single-file executables under 1MB that start instantly.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-8">
            <Link
              href="/docs"
              className="px-6 py-3 bg-cyan-500 hover:bg-cyan-600 text-white font-medium rounded-lg transition-colors"
            >
              Get Started
            </Link>
            <Link
              href="https://github.com/ucharmdev/ucharm"
              className="px-6 py-3 border border-gray-300 dark:border-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800 font-medium rounded-lg transition-colors"
            >
              View on GitHub
            </Link>
          </div>

          {/* Install command */}
          <div className="inline-flex items-center gap-3 px-4 py-2 bg-gray-100 dark:bg-gray-800 rounded-lg font-mono text-sm">
            <span className="text-gray-500">$</span>
            <code>brew install ucharmdev/tap/ucharm</code>
            <button
              className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"
              title="Copy to clipboard"
            >
              <svg
                className="w-4 h-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                />
              </svg>
            </button>
          </div>
        </div>
      </section>

      {/* Terminal Demo Section */}
      <section className="py-16 px-6 bg-gray-50 dark:bg-gray-900/30">
        <div className="max-w-5xl mx-auto">
          <div className="grid md:grid-cols-2 gap-6">
            <Terminal title="deploy.py">{demoOutput}</Terminal>
            <Terminal title="setup.py">{interactiveDemo}</Terminal>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 px-6">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-3xl font-bold text-center mb-12">Why ucharm?</h2>
          <div className="grid md:grid-cols-3 gap-6">
            <FeatureCard
              icon="⚡"
              title="Instant Startup"
              description="< 10ms cold start. No interpreter warm-up, no virtual environment, no waiting."
            />
            <FeatureCard
              icon="📦"
              title="Tiny Binaries"
              description="Single-file executables under 1MB. Universal binaries work on any machine."
            />
            <FeatureCard
              icon="🐍"
              title="Python Syntax"
              description="Write in familiar Python. No new language to learn, just better tooling."
            />
            <FeatureCard
              icon="🎨"
              title="Beautiful Output"
              description="Tables, boxes, progress bars, spinners, and colors built-in. No dependencies."
            />
            <FeatureCard
              icon="💬"
              title="Interactive Prompts"
              description="Select, multiselect, confirm, password input with keyboard navigation."
            />
            <FeatureCard
              icon="🔧"
              title="50+ Modules"
              description="JSON, HTTP, SQLite, regex, subprocess, and more. All implemented in native Zig."
            />
          </div>
        </div>
      </section>

      {/* Code Example Section */}
      <section className="py-20 px-6 bg-gray-50 dark:bg-gray-900/30">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-3xl font-bold text-center mb-4">
            Simple, Expressive API
          </h2>
          <p className="text-center text-gray-600 dark:text-gray-400 mb-8">
            Everything you need to build great CLI apps in a clean, Pythonic
            interface.
          </p>
          <div className="rounded-lg overflow-hidden border border-gray-200 dark:border-gray-800 shadow-lg">
            <div className="bg-gray-100 dark:bg-gray-800 px-4 py-2 flex items-center gap-2">
              <div className="flex gap-1.5">
                <div className="w-3 h-3 rounded-full bg-red-500" />
                <div className="w-3 h-3 rounded-full bg-yellow-500" />
                <div className="w-3 h-3 rounded-full bg-green-500" />
              </div>
              <span className="text-sm text-gray-600 dark:text-gray-400 ml-2">
                app.py
              </span>
            </div>
            <pre className="bg-gray-950 p-4 overflow-x-auto">
              <code className="text-sm text-gray-100 font-mono">
                {codeExample}
              </code>
            </pre>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-6 text-center">
        <div className="max-w-2xl mx-auto">
          <h2 className="text-3xl font-bold mb-4">
            Ready to build something beautiful?
          </h2>
          <p className="text-gray-600 dark:text-gray-400 mb-8">
            Get started in minutes. Ship your first CLI app today.
          </p>
          <Link
            href="/docs"
            className="inline-block px-8 py-4 bg-cyan-500 hover:bg-cyan-600 text-white font-medium rounded-lg transition-colors text-lg"
          >
            Read the Docs
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 px-6 border-t border-gray-200 dark:border-gray-800">
        <div className="max-w-5xl mx-auto flex flex-col md:flex-row justify-between items-center gap-4 text-sm text-gray-600 dark:text-gray-400">
          <div>
            <span className="font-bold">
              <span className="text-cyan-500">u</span>charm
            </span>{" "}
            &mdash; Beautiful CLI apps, tiny binaries.
          </div>
          <div className="flex gap-6">
            <Link
              href="/docs"
              className="hover:text-gray-900 dark:hover:text-gray-100"
            >
              Docs
            </Link>
            <Link
              href="https://github.com/ucharmdev/ucharm"
              className="hover:text-gray-900 dark:hover:text-gray-100"
            >
              GitHub
            </Link>
            <Link
              href="https://github.com/ucharmdev/ucharm/issues"
              className="hover:text-gray-900 dark:hover:text-gray-100"
            >
              Issues
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
