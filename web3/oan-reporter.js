"use strict";
/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║          OBSIDIAN ARCADIA NETWORK - TEST REPORTER            ║
 * ║                  OAN Hacker CLI v1.0                         ║
 * ╚══════════════════════════════════════════════════════════════╝
 * Drop this file in your web3/ root and set in .mocharc.js:
 *   reporter: './oan-reporter.js'
 */

const Mocha  = require("mocha");
const { EVENT_RUN_BEGIN, EVENT_RUN_END, EVENT_TEST_PASS,
        EVENT_TEST_FAIL, EVENT_SUITE_BEGIN, EVENT_SUITE_END,
        EVENT_TEST_PENDING } = Mocha.Runner.constants;

// ── ANSI colour palette ──────────────────────────────────────────
const C = {
  reset:    "\x1b[0m",
  bold:     "\x1b[1m",
  dim:      "\x1b[2m",
  // greens
  neon:     "\x1b[38;2;0;255;65m",       // matrix green
  lime:     "\x1b[38;2;57;255;20m",
  // cyans
  cyan:     "\x1b[38;2;0;255;255m",
  ice:      "\x1b[38;2;100;220;255m",
  // purples / obsidian
  violet:   "\x1b[38;2;180;50;255m",
  obsidian: "\x1b[38;2;140;80;255m",
  // reds / warnings
  crimson:  "\x1b[38;2;255;50;50m",
  orange:   "\x1b[38;2;255;140;0m",
  // neutrals
  ghost:    "\x1b[38;2;80;80;100m",
  silver:   "\x1b[38;2;180;180;200m",
  white:    "\x1b[38;2;230;230;255m",
  // backgrounds
  bgDark:   "\x1b[48;2;5;5;15m",
  bgPass:   "\x1b[48;2;0;30;0m",
  bgFail:   "\x1b[48;2;40;0;0m",
};

const c = (color, str) => `${color}${str}${C.reset}`;
const bold = (color, str) => `${C.bold}${color}${str}${C.reset}`;

// ── ASCII banner ─────────────────────────────────────────────────
function printBanner() {
  const lines = [
    "",
    c(C.obsidian, "  ╔══════════════════════════════════════════════════════════════════╗"),
    c(C.obsidian, "  ║") + bold(C.violet, "   ██████╗  █████╗ ███╗  ██╗") + bold(C.cyan, "   ██████╗  █████╗  ███╗  ██╗") + c(C.obsidian, "  ║"),
    c(C.obsidian, "  ║") + bold(C.violet, "  ██╔═══██╗██╔══██╗████╗ ██║") + bold(C.cyan, "  ██╔═══██╗██╔══██╗ ████╗ ██║") + c(C.obsidian, "  ║"),
    c(C.obsidian, "  ║") + bold(C.violet, "  ██║   ██║███████║██╔██╗██║") + bold(C.cyan, "  ██║   ██║███████║ ██╔██╗██║") + c(C.obsidian, "  ║"),
    c(C.obsidian, "  ║") + bold(C.violet, "  ██║   ██║██╔══██║██║╚████║") + bold(C.cyan, "  ██║   ██║██╔══██║ ██║╚████║") + c(C.obsidian, "  ║"),
    c(C.obsidian, "  ║") + bold(C.violet, "  ╚██████╔╝██║  ██║██║ ╚███║") + bold(C.cyan, "  ╚██████╔╝██║  ██║ ██║ ╚███║") + c(C.obsidian, "  ║"),
    c(C.obsidian, "  ║") + bold(C.violet, "   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚══╝") + bold(C.cyan, "   ╚═════╝ ╚═╝  ╚═╝ ╚═╝  ╚══╝") + c(C.obsidian, "  ║"),
    c(C.obsidian, "  ║") + c(C.ghost, "                                                                  ") + c(C.obsidian, "║"),
    c(C.obsidian, "  ║") + bold(C.neon, "        O B S I D I A N   A R C A D I A   N E T W O R K          ") + c(C.obsidian, "║"),
    c(C.obsidian, "  ║") + c(C.ghost, "              7-Layer Blockchain Protocol  ·  EVM                 ") + c(C.obsidian, "║"),
    c(C.obsidian, "  ╚══════════════════════════════════════════════════════════════════╝"),
    "",
    c(C.ghost, "  ") + c(C.ghost, "▸ ") + c(C.silver, "Initializing test harness") + c(C.ghost, " ··· ") + c(C.neon, "ONLINE"),
    c(C.ghost, "  ") + c(C.ghost, "▸ ") + c(C.silver, "Hardhat network") + c(C.ghost, "          ··· ") + c(C.cyan, "READY"),
    c(C.ghost, "  ") + c(C.ghost, "▸ ") + c(C.silver, "Contract artifacts") + c(C.ghost, "       ··· ") + c(C.lime, "LOADED"),
    "",
    c(C.ghost, "  ─────────────────────────────────────────────────────────────────"),
    "",
  ];
  lines.forEach(l => console.log(l));
}

// ── Layer detection from suite title ────────────────────────────
function layerColor(title) {
  const t = title.toLowerCase();
  if (t.includes("layer 1") || t.includes("l1")) return C.violet;
  if (t.includes("layer 2") || t.includes("l2")) return C.obsidian;
  if (t.includes("layer 3") || t.includes("l3")) return C.cyan;
  if (t.includes("layer 4") || t.includes("l4")) return C.ice;
  if (t.includes("layer 5") || t.includes("l5")) return C.neon;
  if (t.includes("layer 6") || t.includes("l6")) return C.lime;
  if (t.includes("layer 7") || t.includes("l7")) return C.orange;
  if (t.includes("integration")) return C.cyan;
  if (t.includes("security"))    return C.crimson;
  if (t.includes("phase"))       return C.ice;
  return C.silver;
}

// ── Reporter class ───────────────────────────────────────────────
class OANReporter {
  constructor(runner) {
    this._passes   = 0;
    this._failures = 0;
    this._pending  = 0;
    this._depth    = 0;
    this._start    = Date.now();
    this._failed   = [];

    printBanner();

    runner
      .on(EVENT_SUITE_BEGIN, suite => {
        if (!suite.title) return;
        const indent = "  ".repeat(this._depth);
        const col    = layerColor(suite.title);

        if (this._depth === 0) {
          // Top-level suite — big header
          const bar = "═".repeat(Math.min(suite.title.length + 6, 60));
          console.log(`\n${indent}${c(col, "╔" + bar + "╗")}`);
          console.log(`${indent}${c(col, "║")}  ${bold(col, suite.title.toUpperCase())}  ${c(col, "║")}`);
          console.log(`${indent}${c(col, "╚" + bar + "╝")}`);
        } else if (this._depth === 1) {
          console.log(`\n${indent}${c(col, "┌─")} ${bold(col, suite.title)}`);
        } else {
          console.log(`${indent}${c(C.ghost, "│  ")}${c(C.ghost, "◆ ")}${c(C.silver, suite.title)}`);
        }
        this._depth++;
      })

      .on(EVENT_SUITE_END, suite => {
        if (!suite.title) return;
        this._depth = Math.max(0, this._depth - 1);
      })

      .on(EVENT_TEST_PASS, test => {
        this._passes++;
        const indent = "  ".repeat(this._depth);
        const ms     = test.duration || 0;
        const speed  = ms < 50  ? c(C.neon,    `${ms}ms`) :
                       ms < 200 ? c(C.lime,    `${ms}ms`) :
                       ms < 500 ? c(C.orange,  `${ms}ms`) :
                                  c(C.crimson, `${ms}ms`);
        console.log(`${indent}${c(C.neon, "✔")}  ${c(C.white, test.title)}  ${c(C.ghost, speed)}`);
      })

      .on(EVENT_TEST_FAIL, (test, err) => {
        this._failures++;
        this._failed.push({ test, err });
        const indent = "  ".repeat(this._depth);
        console.log(`${indent}${c(C.crimson, "✘")}  ${bold(C.crimson, test.title)}`);
        console.log(`${indent}   ${c(C.orange, "→")} ${c(C.crimson, err.message.split("\n")[0])}`);
      })

      .on(EVENT_TEST_PENDING, test => {
        this._pending++;
        const indent = "  ".repeat(this._depth);
        console.log(`${indent}${c(C.ghost, "⊘")}  ${c(C.ghost, test.title)}`);
      })

      .on(EVENT_RUN_END, () => {
        const elapsed = ((Date.now() - this._start) / 1000).toFixed(1);
        const total   = this._passes + this._failures + this._pending;
        const allPass = this._failures === 0;

        console.log("");
        console.log(c(C.ghost, "  ─────────────────────────────────────────────────────────────────"));
        console.log("");

        if (allPass) {
          console.log(c(C.neon, "  ╔═══════════════════════════════════════╗"));
          console.log(c(C.neon, "  ║") + bold(C.neon, "   ✔  ALL SYSTEMS OPERATIONAL             ") + c(C.neon, "║"));
          console.log(c(C.neon, "  ╚═══════════════════════════════════════╝"));
        } else {
          console.log(c(C.crimson, "  ╔═══════════════════════════════════════╗"));
          console.log(c(C.crimson, "  ║") + bold(C.crimson, `   ✘  ${this._failures} SYSTEM FAILURE(S) DETECTED        `) + c(C.crimson, "║"));
          console.log(c(C.crimson, "  ╚═══════════════════════════════════════╝"));
        }

        console.log("");
        console.log(
          `  ${bold(C.neon,    `${this._passes}`)}  ${c(C.ghost, "passing")}` +
          `   ${bold(C.crimson, `${this._failures}`)}  ${c(C.ghost, "failing")}` +
          `   ${bold(C.silver,  `${this._pending}`)}  ${c(C.ghost, "pending")}` +
          `   ${c(C.ghost, "─")}  ${c(C.ice, elapsed + "s")}`
        );

        // Pass bar
        const barWidth = 50;
        const filled   = Math.round((this._passes / total) * barWidth);
        const bar = c(C.neon, "█".repeat(filled)) + c(C.crimson, "█".repeat(barWidth - filled));
        console.log(`\n  ${c(C.ghost, "[")}${bar}${c(C.ghost, "]")}  ${c(C.silver, Math.round(this._passes/total*100) + "%")}\n`);

        // Failure details
        if (this._failed.length > 0) {
          console.log(c(C.crimson, "  ── FAILURES ──────────────────────────────────────────────────────"));
          this._failed.forEach(({ test, err }, i) => {
            console.log("");
            console.log(`  ${bold(C.crimson, `${i + 1})`)} ${bold(C.orange, test.fullTitle())}`);
            console.log(`     ${c(C.silver, err.message)}`);
            if (err.actual !== undefined && err.expected !== undefined) {
              console.log(`     ${c(C.ghost, "expected:")} ${c(C.neon, JSON.stringify(err.expected))}`);
              console.log(`     ${c(C.ghost, "actual:  ")} ${c(C.crimson, JSON.stringify(err.actual))}`);
            }
          });
          console.log("");
        }

        console.log(c(C.ghost, "  ─────────────────────────────────────────────────────────────────"));
        console.log(c(C.ghost, `\n  OAN Test Suite · Hardhat · ${new Date().toISOString()}\n`));
      });
  }
}

module.exports = OANReporter;