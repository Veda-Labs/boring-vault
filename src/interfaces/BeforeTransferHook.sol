// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault@939c77e25473dff3ed18fa104f004f7afd13452e — file:audit/spearbit-boring-vault-arctic-0.pdf
pragma solidity 0.8.21;

interface BeforeTransferHook {
    function beforeTransfer(address from, address to, address operator) external view;
}
