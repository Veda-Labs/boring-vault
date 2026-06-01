// safe summaries to enhance performance

methods {
    // lib/openzeppelin-contracts/contracts/utils/math/Math.sol
    function _.mulDivDown(uint256 x, uint256 y, uint256 denominator) internal => cvlMulDivDown(x, y, denominator) expect uint256;
    function _.mulDivUp(uint256 x, uint256 y, uint256 denominator) internal => cvlMulDivUp(x, y, denominator) expect uint256;
    function _.sqrt(uint256 a) internal => cvlSqrt(a) expect uint256;
    function _.average(uint256 a, uint256 b) internal => cvlAverage(a, b) expect uint256;
    function _.ternary(bool condition, uint256 a, uint256 b) internal => cvlTernary(condition, a, b) expect uint256;
    function _.zeroFloorSub(uint256 x, uint256 y) internal => cvlZeroFloorSub(x, y) expect (uint256);

}

function cvlZeroFloorSub(uint256 x, uint256 y) returns uint256 {
    if (x > y) return require_uint256(x - y);
    else return 0;
}

function cvlMulDivDown(uint256 x, uint256 y, uint256 denominator) returns uint256 {
    require denominator > 0;
    mathint res = x * y / denominator;
    return require_uint256(res);
}

function cvlMulDivUp(uint256 x, uint256 y, uint256 denominator) returns uint256 
{
    require denominator > 0;
    return require_uint256((x * y + denominator - 1) / denominator);
}

function cvlSqrt(uint256 a) returns uint256 {
    mathint a_mathint = to_mathint(a);
    uint256 sqrt_a;
    require
        sqrt_a * sqrt_a <= a_mathint &&
        (sqrt_a + 1) * (sqrt_a + 1) > a_mathint;
    return sqrt_a;
}

function cvlAverage(uint256 a, uint256 b) returns uint256 {
    return require_uint256((a + b) / 2);
}

function cvlTernary(bool condition, uint256 a, uint256 b) returns uint256 {
    return condition ? a : b;
}