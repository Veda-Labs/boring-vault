methods {
    function _.canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external => CVL_canCall(user, target, functionSig) expect bool;
}

ghost mapping(address => mapping(address => mapping(bytes4 => bool))) ghost_canCall;

function CVL_canCall(address user, address target, bytes4 functionSig) returns bool {
    return ghost_canCall[user][target][functionSig];
}