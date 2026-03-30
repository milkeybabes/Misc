#!/usr/bin/env python3

import sys
import os
import glob
import csv
import subprocess

# ------------------------------------------------------------
# Usage:
#   python zx0_batch_compress.py <input> <tool> [--extension .zx0]
#
# Examples:
#   python zx0_batch_compress.py *.map compress.exe
#   python zx0_batch_compress.py *.chr zx0.exe --extension .pack
#   python zx0_batch_compress.py assets/*.bin mytool.exe
#
# Behavior:
#   - Runs external tool: tool input output
#   - Output format: inputname_ext.outputext
#     e.g. file.map -> file_map.zx0
# ------------------------------------------------------------


DEFAULT_EXT = ".zx0"


def get_files(path_pattern):
    if os.path.isdir(path_pattern):
        return sorted(
            f for f in glob.glob(os.path.join(path_pattern, "*"))
            if os.path.isfile(f)
        )
    return sorted(
        f for f in glob.glob(path_pattern)
        if os.path.isfile(f)
    )


def normalise_extension(ext):
    if not ext:
        return DEFAULT_EXT
    if not ext.startswith("."):
        return "." + ext
    return ext


def get_tool_folder_name(tool_path):
    tool_name = os.path.basename(tool_path)
    base, _ = os.path.splitext(tool_name)
    return base if base else tool_name


def build_output_filename(input_file, out_ext):
    base = os.path.splitext(os.path.basename(input_file))[0]
    orig_ext = os.path.splitext(input_file)[1].lstrip(".")

    if orig_ext:
        return f"{base}_{orig_ext}{out_ext}"
    return f"{base}{out_ext}"


def ensure_folder(path):
    os.makedirs(path, exist_ok=True)


def file_size(path):
    try:
        return os.path.getsize(path)
    except OSError:
        return -1


def run_tool(tool, infile, outfile):
    try:
        result = subprocess.run(
            [tool, infile, outfile],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return {
            "returncode": result.returncode,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
            "error": ""
        }
    except Exception as e:
        return {
            "returncode": -1,
            "stdout": "",
            "stderr": "",
            "error": str(e)
        }


def write_csv(csv_path, rows):
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "tool",
            "input_file",
            "output_file",
            "input_size",
            "output_size",
            "ratio_percent",
            "return_code",
            "status",
            "stdout",
            "stderr",
            "error"
        ])
        writer.writerows(rows)


def main():
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python zx0_batch_compress.py <input_wildcard_or_folder> <tool.exe> [--extension .zx0]")
        sys.exit(1)

    args = sys.argv[1:]

    input_spec = args[0]
    tool = args[1]
    out_ext = DEFAULT_EXT

    if "--extension" in args:
        idx = args.index("--extension")
        if idx + 1 >= len(args):
            print("Error: --extension requires a value")
            sys.exit(1)
        out_ext = normalise_extension(args[idx + 1])

    files = get_files(input_spec)
    if not files:
        print("No files found.")
        sys.exit(1)

    tool_folder = get_tool_folder_name(tool)
    ensure_folder(tool_folder)

    csv_path = os.path.join(tool_folder, f"{tool_folder}_results.csv")
    csv_rows = []

    print(f"Tool:   {tool}")
    print(f"Folder: {tool_folder}")
    print(f"Files:  {len(files)}")
    print()

    ok_count = 0
    fail_count = 0

    for infile in files:
        out_name = build_output_filename(infile, out_ext)
        outfile = os.path.join(tool_folder, out_name)

        input_size = file_size(infile)
        result = run_tool(tool, infile, outfile)

        output_size = file_size(outfile) if os.path.exists(outfile) else -1

        if result["returncode"] == 0 and output_size >= 0:
            status = "OK"
            ok_count += 1
        else:
            status = "FAIL"
            fail_count += 1

        ratio_percent = ""
        if input_size > 0 and output_size >= 0:
            ratio_percent = f"{(output_size / input_size) * 100:.2f}"

        print(f"[{status}] {infile} -> {outfile}")
        if input_size >= 0 and output_size >= 0:
            print(f"       {input_size} -> {output_size} bytes ({ratio_percent}%)")
        elif input_size >= 0:
            print(f"       {input_size} -> output not created")

        if result["stderr"]:
            print(f"       stderr: {result['stderr']}")
        if result["error"]:
            print(f"       error: {result['error']}")

        csv_rows.append([
            tool_folder,
            infile,
            outfile,
            input_size,
            output_size,
            ratio_percent,
            result["returncode"],
            status,
            result["stdout"],
            result["stderr"],
            result["error"]
        ])

    write_csv(csv_path, csv_rows)

    print()
    print(f"Done. OK={ok_count} FAIL={fail_count}")
    print(f"CSV log: {csv_path}")


if __name__ == "__main__":
    main()