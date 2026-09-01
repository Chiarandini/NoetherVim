import { expect, test } from "vitest";
import { add } from "./main";

test("passes", () => {
    expect(add(1, 2)).toBe(3);
});

test("fails", () => {
    expect(add(1, 2)).toBe(4);
});
