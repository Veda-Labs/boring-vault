// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {DeployArcticArchitectureWithConfigScript} from
    "script/ArchitectureDeployments/DeployArcticArchitectureWithConfig.s.sol";

// Thin harness: exposes internal helpers as external so Test can call them.
contract MetadataHarness is DeployArcticArchitectureWithConfigScript {
    function deploymentCommit() external view returns (string memory) {
        return _deploymentCommit();
    }

    function parseAuditLine(string memory sourcePath)
        external
        returns (string memory auditCommit, string memory auditUrl)
    {
        return _parseAuditLine(sourcePath);
    }
}

contract DeployMetadataHelpersTest is Test {
    MetadataHarness harness;

    function setUp() public {
        harness = new MetadataHarness();
    }

    // -------------------------------------------------------------------------
    // _deploymentCommit
    // -------------------------------------------------------------------------

    function test_deploymentCommit_is40HexChars() public {
        string memory commit = harness.deploymentCommit();
        bytes memory b = bytes(commit);
        assertEq(b.length, 40, "deploymentCommit must be 40 chars");
        for (uint256 i; i < 40; i++) {
            bytes1 c = b[i];
            bool isHex = (c >= "0" && c <= "9") || (c >= "a" && c <= "f") || (c >= "A" && c <= "F");
            assertTrue(isHex, "deploymentCommit must be hex");
        }
    }

    // -------------------------------------------------------------------------
    // _parseAuditLine — fixture-based (self-contained, not tied to source files)
    // -------------------------------------------------------------------------

    // Writes a file whose 5th line is a valid "// Last audited:" comment and
    // verifies that _parseAuditLine extracts the correct commit + URL.
    function test_parseAuditLine_parsesValidLine() public {
        string memory fixture = "./test/fixtures/audit_fixture.sol";
        vm.writeFile(
            fixture,
            "// SPDX-License-Identifier: MIT\n"
            "// line 2\n"
            "// line 3\n"
            "// line 4\n"
            "// Last audited: boring-vault@3c768bd068af856b5de3def86b1940676847eb9d \xe2\x80\x94 https://example.com/audit\n"
            "pragma solidity 0.8.21;\n"
        );
        (string memory commit, string memory url) = harness.parseAuditLine(fixture);
        assertEq(commit, "3c768bd068af856b5de3def86b1940676847eb9d", "wrong commit");
        assertEq(url, "https://example.com/audit", "wrong url");
    }

    // When line 5 is a normal pragma (no audit annotation), both fields are "".
    function test_parseAuditLine_noAuditLine_returnsEmpty() public {
        string memory fixture = "./test/fixtures/no_audit_fixture.sol";
        vm.writeFile(
            fixture,
            "// SPDX-License-Identifier: MIT\n"
            "// line 2\n"
            "// line 3\n"
            "// line 4\n"
            "pragma solidity 0.8.21;\n"
        );
        (string memory commit, string memory url) = harness.parseAuditLine(fixture);
        assertEq(commit, "", "commit should be empty when no audit line");
        assertEq(url, "", "url should be empty when no audit line");
    }

    // File with fewer than 4 newlines → ("", "").
    function test_parseAuditLine_tooShort_returnsEmpty() public {
        string memory fixture = "./test/fixtures/short_fixture.sol";
        vm.writeFile(fixture, "// only one line\n");
        (string memory commit, string memory url) = harness.parseAuditLine(fixture);
        assertEq(commit, "");
        assertEq(url, "");
    }

    // Non-hex chars after '@' (e.g. an email address) → ("", "").
    function test_parseAuditLine_nonHexAfterAt_returnsEmpty() public {
        string memory fixture = "./test/fixtures/email_fixture.sol";
        vm.writeFile(
            fixture,
            "// SPDX-License-Identifier: MIT\n"
            "// line 2\n"
            "// line 3\n"
            "// line 4\n"
            "// Contact: name@example.com for audit questions\n"
            "pragma solidity 0.8.21;\n"
        );
        (string memory commit, string memory url) = harness.parseAuditLine(fixture);
        assertEq(commit, "", "non-hex after @ should return empty");
        assertEq(url, "");
    }

    // Wrong separator (hyphen instead of em-dash) → ("", "").
    function test_parseAuditLine_wrongSeparator_returnsEmpty() public {
        string memory fixture = "./test/fixtures/wrong_sep_fixture.sol";
        vm.writeFile(
            fixture,
            "// SPDX-License-Identifier: MIT\n"
            "// line 2\n"
            "// line 3\n"
            "// line 4\n"
            "// Last audited: boring-vault@3c768bd068af856b5de3def86b1940676847eb9d - https://example.com/audit\n"
            "pragma solidity 0.8.21;\n"
        );
        (string memory commit, string memory url) = harness.parseAuditLine(fixture);
        assertEq(commit, "", "wrong separator should return empty");
        assertEq(url, "");
    }

    // Nonexistent path → ("", "") instead of aborting.
    function test_parseAuditLine_missingFile_returnsEmpty() public {
        (string memory commit, string memory url) =
            harness.parseAuditLine("./test/fixtures/does_not_exist.sol");
        assertEq(commit, "");
        assertEq(url, "");
    }
}
