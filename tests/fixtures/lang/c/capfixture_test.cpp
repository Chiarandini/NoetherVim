#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"

int add(int a, int b) { return a + b; }

TEST_CASE("passes") {
    CHECK(add(1, 2) == 3);
}

TEST_CASE("fails") {
    CHECK(add(1, 2) == 4);
}
