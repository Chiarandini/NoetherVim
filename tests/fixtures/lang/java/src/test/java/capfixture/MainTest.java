package capfixture;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class MainTest {
    @Test
    void passes() {
        assertEquals(3, Main.add(1, 2));
    }

    @Test
    void fails() {
        assertEquals(4, Main.add(1, 2));
    }
}
