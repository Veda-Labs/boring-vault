#!/usr/bin/env python3
"""
Convert Solidity compilation output JSON to standard JSON input format.

This script replicates the logic from:
boring-synthesis/crates/synthesis/src/bin/convert_solidity_artifacts.rs
"""

import json
import os
import sys
from pathlib import Path
from typing import Optional


def should_process_file(data: dict) -> bool:
    """
    Check if the compilation target starts with 'src/' or 'lib/solmate/src'.
    Returns True if file should be processed, False otherwise.
    """
    metadata = data.get("metadata")

    # Try rawMetadata if metadata is not a dict
    if metadata is None:
        raw_metadata = data.get("rawMetadata")
        if raw_metadata and isinstance(raw_metadata, str):
            try:
                metadata = json.loads(raw_metadata)
            except json.JSONDecodeError:
                return False

    if not isinstance(metadata, dict):
        return False

    settings = metadata.get("settings", {})
    compilation_target = settings.get("compilationTarget", {})

    if not isinstance(compilation_target, dict):
        return False

    # Check if any compilation target path starts with allowed prefixes
    for path in compilation_target.keys():
        if path.startswith("src/") or path.startswith("lib/solmate/src"):
            return True

    return False


def convert_to_standard_json_input(data: dict) -> dict:
    """
    Convert a compiled Solidity output JSON to standard JSON input format.

    Preserves the original metadata in a '_metadata' field for verification purposes.
    """
    # Extract metadata
    metadata = data.get("metadata")
    if metadata is None:
        raw_metadata = data.get("rawMetadata")
        if raw_metadata and isinstance(raw_metadata, str):
            metadata = json.loads(raw_metadata)
        else:
            raise ValueError("No metadata found in JSON file")

    if not isinstance(metadata, dict):
        raise ValueError("Metadata is not a valid object")

    # Preserve original metadata for verification (compiler version, compilation target)
    original_metadata = metadata

    # Extract settings from metadata
    settings = metadata.get("settings", {})
    metadata_settings = settings.get("metadata", {})

    # Build sources - only keep content, discard keccak256, urls, license
    sources = metadata.get("sources", {})
    converted_sources = {}

    for file_path, source_info in sources.items():
        if isinstance(source_info, dict) and "content" in source_info:
            converted_sources[file_path] = {"content": source_info["content"]}

    # Build the standard JSON input format
    standard_json = {
        "language": "Solidity",
        "sources": converted_sources,
        "settings": {
            "remappings": settings.get("remappings", []),
            "optimizer": settings.get("optimizer", {"enabled": True, "runs": 200}),
            "metadata": {
                "useLiteralContent": metadata_settings.get("useLiteralContent", True),
                "bytecodeHash": metadata_settings.get("bytecodeHash", "ipfs"),
                "appendCBOR": True,
            },
            "outputSelection": {
                "*": {
                    "*": [
                        "abi",
                        "evm.bytecode.object",
                        "evm.bytecode.sourceMap",
                        "evm.bytecode.linkReferences",
                        "evm.deployedBytecode.object",
                        "evm.deployedBytecode.sourceMap",
                        "evm.deployedBytecode.linkReferences",
                        "evm.deployedBytecode.immutableReferences",
                        "evm.methodIdentifiers",
                        "metadata",
                    ]
                }
            },
            "evmVersion": settings.get("evmVersion", "shanghai"),
            "viaIR": False,
            "libraries": settings.get("libraries", {}),
        },
        # Preserve original Foundry metadata for verification
        # Contains compiler version and compilation target needed by block explorers
        "_metadata": original_metadata,
    }

    return standard_json


def process_file(
    input_path: Path, artifacts_dir: Path, output_dir: Path
) -> Optional[bool]:
    """
    Process a single JSON file and save the converted output.
    Returns True if processed, None if skipped, raises on error.
    """
    # Read and parse input JSON
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Skip if compilation target doesn't match filter
    if not should_process_file(data):
        return None

    # Convert to standard JSON input format
    standard_json = convert_to_standard_json_input(data)

    # Determine output path (preserve relative structure)
    relative_path = input_path.relative_to(artifacts_dir)
    output_path = output_dir / relative_path

    # Create parent directories
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Write output with pretty formatting
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(standard_json, f, indent=2)

    return True


def main():
    # Configuration from environment or defaults
    input_dir = Path(os.environ.get("INPUT_DIR", "out"))
    output_dir = Path(os.environ.get("OUTPUT_DIR", "standard-json-out"))

    if not input_dir.exists():
        print(f"Error: Input directory '{input_dir}' not found", file=sys.stderr)
        sys.exit(1)

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Processing JSON files in: {input_dir}")
    print(f"Output directory: {output_dir}")

    processed = 0
    skipped = 0
    errors = 0

    # Walk through all JSON files
    for json_file in input_dir.rglob("*.json"):
        try:
            result = process_file(json_file, input_dir, output_dir)
            if result is True:
                processed += 1
                print(f"Converted: {json_file}")
            else:
                skipped += 1
        except Exception as e:
            print(f"Error processing {json_file}: {e}", file=sys.stderr)
            errors += 1

    print(f"\nProcessing complete!")
    print(f"  Processed: {processed}")
    print(f"  Skipped: {skipped}")
    if errors > 0:
        print(f"  Errors: {errors}")
        sys.exit(1)


if __name__ == "__main__":
    main()
