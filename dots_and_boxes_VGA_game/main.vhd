library ieee;
use ieee.std_logic_1164.all;

package player_colors is
      type color_array is array (0 to 2) of std_logic_vector(7 downto 0);
      constant PLAYER_1_COLOR : color_array := ("11111111","00000000","00000000"); -- Red
    constant PLAYER_2_COLOR : color_array := ("00000000","11111111","00000000"); -- Green
    constant PLAYER_3_COLOR : color_array := ("00000000","00000000","11111111"); -- Blue
    constant DOT_COLOR        : color_array := ("11111111","11111111","11111111"); -- White
    constant BACKGROUND        : color_array := ("00000000","00000000","00000000"); -- Black
    constant R : integer := 0;
    constant G : integer := 1;
    constant B : integer := 2;
end package player_colors;

library ieee;
use ieee.std_logic_1164.all;

package data_access is
    constant LEFT : integer := 0;
    constant UP : integer := 1;
    constant RIGHT : integer := 2;
    constant DOWN : integer := 3;
    type connection_data is array (0 to 3) of std_logic_vector(1 downto 0);
    type y_data is array (0 to 7) of connection_data;
    type connection_grid is array (0 to 7) of y_data;
    subtype box_ownership is std_logic_vector(1 downto 0);
    type box_column is array (0 to 6) of box_ownership;
    type box_grid is array (0 to 6) of box_column;
end package data_access;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.data_access.all;

entity main_game_loop is
    port(
              reset: in std_logic;
            clk_50: in std_logic;
              left: in std_logic;
              up: in std_logic;
              right: in std_logic;
              down: in std_logic;
              x: in std_logic_vector(2 downto 0);
              y: in std_logic_vector(2 downto 0);
              player_indicator_leds: out std_logic_vector(17 downto 0);
              score_leds: out std_logic_vector(8 downto 0);
              red_out: out std_logic_vector(7 downto 0);
              green_out: out std_logic_vector(7 downto 0);
              blue_out: out std_logic_vector(7 downto 0);
            hs_out: out std_logic;
              vs_out: out std_logic;
              sync: out std_logic;
              blank: out std_logic;
              clk25_out: out std_logic
        );
end main_game_loop;

architecture state_machine of main_game_loop is

      component display
          port(
                clk_50: in std_logic;
                  red_out: out std_logic_vector(7 downto 0);
                  green_out: out std_logic_vector(7 downto 0);
                  blue_out: out std_logic_vector(7 downto 0);
                hs_out, vs_out, sync, blank, clk25_out: out std_logic;
                  game_end: in std_logic;
                winning_player: in std_logic_vector(1 downto 0);
                connections: in connection_grid;
                boxes: in box_grid
            );
    end component;

    component led_player_indicator
        port(
                player: in std_logic_vector(1 downto 0);
                leds: out std_logic_vector(17 downto 0)
            );
    end component;

      component move_verification
          port(
                  clk, reset: in std_logic;
                valid, invalid: out std_logic;
                  x, y: in std_logic_vector(2 downto 0);
                direction: in std_logic_vector(3 downto 0);
                  connections: out connection_grid;
                  player: in std_logic_vector(1 downto 0)
            );
      end component;

    component scoring
        port(
                clk: in std_logic;
                reset: in std_logic;
                player: in std_logic_vector(1 downto 0);
                winner: out std_logic_vector(1 downto 0);
                score: out std_logic_vector(8 downto 0);
                  x_cord, y_cord: in std_logic_vector(2 downto 0);
                  direction: in std_logic_vector(3 downto 0);
                  state: in std_logic_vector(1 downto 0);
                  full, empty: out std_logic;
                  connections: in connection_grid;
                boxes: out box_grid;
                  player_scored: out std_logic
            );
    end component;

    signal connections: connection_grid := (others => (others => (others => (others => '0'))));
    signal boxes: box_grid := (others => (others => (others => '0')));
      signal player_latch, player, winning_player, current_player, next_player: std_logic_vector(1 downto 0) := "01";
    signal valid, invalid, valid_latch, invalid_latch, full, empty, full_latch, empty_latch, game_end, button_pressed, player_scored, clk_25: std_logic := '0';
    signal direction, direction_latch : std_logic_vector(3 downto 0) := "0000";
    signal current_state: std_logic_vector(1 downto 0) := "00";
    signal x_latch, y_latch : std_logic_vector(2 downto 0) := "000";
    signal state, next_state : std_logic_vector(1 downto 0) := "00";
begin
    clk25_out <= clk_25; 
    game_loop : process (clk_50) is
      begin
        if (clk_50'event and clk_50 = '1') then
              full_latch <= full;
              empty_latch <= empty;
            valid_latch <= valid;
            invalid_latch <= invalid;
            if (reset = '1') then
                state <= "00";
                next_player <= "01";
            else
                state <= next_state;
            end if;
              case state is
                  when "00" =>
                      if (button_pressed = '1') then
                          next_state <= "01";
                        player_latch <= current_player;
                        x_latch <= x;
                        y_latch <= y;
                        direction_latch <= direction;
                      else
                          next_state <= "00";
                      end if;
                    game_end <= '0';
                  when "01" =>
                      if (valid_latch = '1') then
                        next_state <= "10";
                    elsif (invalid_latch = '1') then
                        next_state <= "00";
                    else
                        next_state <= "01";
                    end if;
                    game_end <= '0';
                  when "10" =>
                      case current_player is
                        when "01" => next_player <= "10";
                        when "10" => next_player <= "11";
                        when "11" => next_player <= "01";
                        when others => next_player <= "01";
                    end case;
                      if (full_latch = '1') then
                        next_state <= "11";
                          next_player <= winning_player;
                    elsif (empty_latch = '1') then
                        next_state <= "00";
                        if (player_scored = '1') then
                          next_player <= current_player;
                        end if;
                    end if;
                    game_end <= '0';
                  when "11" =>
                      next_state <= "11";
                    game_end <= '1';
                  when others =>
                      next_state <= "00";
                    game_end <= '0';
            end case;
              current_player <= next_player;
              current_state <= state;
             player <= current_player;
        end if;
    end process game_loop;
    disp : display port map(clk_50, red_out, green_out, blue_out, hs_out, vs_out, sync, blank, clk_25, game_end, winning_player, connections, boxes);
    leds : led_player_indicator port map(player, player_indicator_leds);
    verify : move_verification port map(clk_50, reset, valid, invalid, x_latch, y_latch, direction_latch, connections, player_latch);
    scorer : scoring port map(clk_50, reset, player_latch, winning_player, score_leds, x_latch, y_latch, direction_latch, current_state, full, empty, connections, boxes, player_scored);
    direction <= "1000" when left = '0' else
                  "0100" when up = '0' else
                  "0010" when right = '0' else
                  "0001" when down = '0' else
                  "0000";
    button_pressed <= not (left and up and down and right);
end state_machine;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.player_colors.all;
use work.data_access.all;
-- Manage VGA, displaying dot grid, colored connections, colored filled boxes, and the winner at the end
entity display is
    port(
            clk_50: in std_logic;                            -- DE2 Clock
              red_out: out std_logic_vector(7 downto 0);        -- VGA R
              green_out: out std_logic_vector(7 downto 0);    -- VGA G
              blue_out: out std_logic_vector(7 downto 0);        -- VGA B
            hs_out: out std_logic;                            -- Horizontal Sync
              vs_out: out std_logic;                            -- Vertical Sync
              sync: out std_logic;                            -- Unused
              blank: out std_logic;                            -- Tie to 1 for color
              clk25_out: out std_logic;                        -- VGA Clock
              game_end: in std_logic;                            -- Display winner
              winning_player: in std_logic_vector(1 downto 0);-- Player: R-01 G-10 B-11
              connections: in connection_grid;                -- Grid of connections
            boxes: in box_grid                                -- Grid of filled boxes
        );
end display;

architecture behavior of display is
    signal clk25 : std_logic := '0';                                     -- Internal Clock aligned with VGA
    signal horizontal_counter : integer := 0;    -- tracks what column we are on
    signal vertical_counter : integer := 0;    -- tracks what row we are on
begin
    clk25_out <= clk25;
    sync <= '0';
    blank <= '1' when
        ((horizontal_counter < 640) and (vertical_counter < 480))
    else
        '0';

    -- Divide the 50 MHz clock because VGA pixel clock is 25MHz
    process (clk_50)
    begin
        if clk_50'event and clk_50='1'
        then
            if (clk25 = '0')
            then
                clk25 <= '1';
            else
                clk25 <= '0';
            end if;
        end if;
    end process;

    -- Draw game state
    process (clk25)
        variable dot_pixel : std_logic;                         -- 1 where grid should be drawn
        variable connection_pixel : std_logic;                    -- 1 where a connection should be drawn
        variable connection_color : color_array;                -- color of current connection
        variable connection_direction: integer;                    -- left up down right
        variable fill_pixel : std_logic;                        -- 1 where boxes are filled
        variable fill_color : color_array;                        -- color of current filled box
        variable final_color : color_array;                        -- final color of current pixel
        variable connection_num : std_logic_vector (1 downto 0);-- tracks the player that owns connection
        variable box_num : std_logic_vector (1 downto 0);        -- tracks box owner
    begin
        if clk25'event and clk25 = '1'
        then
              dot_pixel := '0';
            connection_pixel := '0';
            fill_pixel := '0';
                                ----- Check for Hsync and Vsync -----
        -- signals should be recieved in order: pixels, front porch, sync, back porch

        -- H Front porch: 0.6 us (15 clk cycles)
        -- Horizontal timing spec: 3.8 us for Hsync (95 clk cycles) but after 640 + 15 (front porch)
            if (horizontal_counter >= 655)
            and (horizontal_counter < 750) -- 655 + 95 clk cycles
            then
                hs_out <= '0';
            else
                hs_out <= '1';
            end if;
        -- H Back porch: 1.9 us (47 clk cycles)

        -- V Front porch: 10 lines
        -- Vertical timing spec: 2 lines for Vsync but after 480 + 10 (front porch)
            if (vertical_counter >= 490)
                and (vertical_counter < 492) -- 490 + 2 (sync)
            then
                vs_out <= '0';
            else
                vs_out <= '1';
            end if;
        -- V Back porch: 33 lines

                                ----- Update pixel position -----
            horizontal_counter <= horizontal_counter+1;
            if (horizontal_counter=797) -- new line at 797, exactly 640 + 15 (front porch) + 95 (sync) + 47 (back porch)
            then
                vertical_counter <= vertical_counter+1;
                horizontal_counter <= 0;
            end if;
            if (vertical_counter=525) -- reset at 525, exactly 480 + 10 (front porch) + 2 (sync) + 33 (back porch)
                then
                    vertical_counter <= 0;
            end if;

                                ----- Determine if we are on a dot -----
            if (
                (((horizontal_counter - 20) mod 40) < 8) -- -20 pushes the first dot forward
                and (horizontal_counter >= 160) -- 40 * 4, centering
                and (horizontal_counter < 488) -- 160 + 40 * 8 + 8
                and (((vertical_counter - 20) mod 40) < 8)
                and (vertical_counter >= 80) -- 40 * 2, centering
                and (vertical_counter < 408) -- 80 + 40 * 8 + 8
                )
            then
                dot_pixel := '1';
            end if;

                                ----- Determine if we are on a connection and set connection color -----
            -- check if within line draw region
            if (
                (horizontal_counter >= 182) -- 40 * 4 + 22, centering and aligning
                and (horizontal_counter < 466) -- 182 + 40 * 7 + 4
                and (vertical_counter >= 102) -- 40 * 2 + 22, centering and aligning
                and (vertical_counter < 386) -- 102 + 40 * 7 + 4
                )
            then
                -- check if on a horizontal line
                if (((vertical_counter - 22) mod 40) < 4) -- -22 pushes the line forward
                then
                      -- check the connections of dot to left of us
                    if (connections((horizontal_counter-182)/40)((vertical_counter-102)/40)(RIGHT) /= "00")
                    then
                        connection_pixel := '1';
                        connection_num := connections((horizontal_counter-182)/40)((vertical_counter-102)/40)(RIGHT);
                    end if;
                -- check if on a vertical line
                elsif (((horizontal_counter - 22) mod 40) < 4)
                  then
                -- check the connections of dot above us
                    if (connections((horizontal_counter-182)/40)((vertical_counter-102)/40)(DOWN) /= "00")
                    then
                        connection_pixel := '1';
                        connection_num := connections((horizontal_counter-182)/40)((vertical_counter-102)/40)(DOWN);
                    end if;
                end if;
            end if;

            -- Determine connection color
            if (connection_pixel = '1')
            then
                if (connection_num = "01")
                then
                    connection_color := PLAYER_1_COLOR;
                elsif (connection_num = "10")
                then
                    connection_color := PLAYER_2_COLOR;
                elsif (connection_num = "11")
                then
                    connection_color := PLAYER_3_COLOR;
                else
                    connection_color := BACKGROUND;
                end if;
            end if;

                                ----- Determine if we are on a filled box and set fill color -----
            if (
                (
                (((horizontal_counter - 28) mod 40) < 32) -- -28 pushes the first box forward
                and
                (((vertical_counter - 28) mod 40) < 32)
                )
                and (horizontal_counter >= 188) -- 40 * 4 + 28, centering and aligning
                and (horizontal_counter < 460) -- 188 + 40 * 7 - 8
                and (vertical_counter >= 108) -- 40 * 2 + 28, centering and aligning
                and (vertical_counter < 380) -- 108 + 40 * 7 - 8
                )
            then
                -- check the color of the box
                box_num := boxes((horizontal_counter-182)/40)((vertical_counter-102)/40);
                if (box_num = "01")
                then
                    fill_color := PLAYER_1_COLOR;
                    fill_pixel := '1';
                elsif (box_num = "10")
                then
                    fill_color := PLAYER_2_COLOR;
                    fill_pixel := '1';
                elsif (box_num = "11")
                then
                    fill_color := PLAYER_3_COLOR;
                    fill_pixel := '1';
                else
                    fill_color := BACKGROUND;
                end if;
            end if;

                                ----- Final pixel color determination -----
            if (game_end = '1') -- Display winner color
            then
                if (winning_player = "01")
                then
                    final_color := PLAYER_1_COLOR;
                elsif (winning_player = "10")
                then
                    final_color := PLAYER_2_COLOR;
                elsif (winning_player = "11")
                then
                    final_color := PLAYER_3_COLOR;
                else
                    final_color := BACKGROUND;
                end if;
            elsif (connection_pixel = '1')    -- Display connections above boxes
            then
                final_color := connection_color;
            elsif (fill_pixel = '1')        -- Display filled boxes
            then
                final_color := fill_color;
            elsif (dot_pixel = '1')            -- Display dot grid lowest level
            then
                final_color := DOT_COLOR;
            else
                final_color := BACKGROUND;
            end if;

            red_out <= final_color(R);
            green_out <= final_color(G);
            blue_out <= final_color(B);
        end if;
    end process;



end behavior;



----verification module--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.data_access.all;
entity move_verification is
    port(
              clk, reset: in std_logic;    --clk needed to keep track of game state
            valid, invalid: out std_logic;
            x, y: in std_logic_vector(2 downto 0);
            direction: in std_logic_vector(3 downto 0);
              connections: out connection_grid;
              player: in std_logic_vector(1 downto 0)
    );
end move_verification;


architecture verification of move_verification is
    signal connection_register: connection_grid := (others => (others => (others => (others => '0'))));

    --shared signals
    signal direction_index: integer range 0 to 3;
    signal opposite: integer range 0 to 3;
    signal x_next, y_next: integer range -1 to 8;    --extended both ways for checking boundaries
    signal no_input: boolean;
    signal valid_internal: std_logic := '0';
begin
    connections <= connection_register;

    --process to set coordinates and direction
    process(x, y, direction, player)
          variable x_int, y_int: integer range 0 to 7;
    begin
          --convert coordinates to integers
        x_int := to_integer(unsigned(x));
        y_int := to_integer(unsigned(y));

        --default values
        no_input <= false;
        x_next <= x_int;
        y_next <= y_int;
        direction_index <= LEFT;
        opposite <= RIGHT;

        --decode direction
        if (direction(3) = '1') then         --LEFT
            direction_index <= LEFT;
            opposite <= RIGHT;
            x_next <= x_int - 1;
        elsif (direction(2) = '1') then     --UP
              direction_index <= UP;
            opposite <= DOWN;
            y_next <= y_int - 1;
        elsif (direction(1) = '1') then     --RIGHT
              direction_index <= RIGHT;
            opposite <= LEFT;
            x_next <= x_int + 1;
        elsif (direction(0) = '1') then     --DOWN
              direction_index <= DOWN;
            opposite <= UP;
            y_next <= y_int + 1;
        else
            --no direction
            --valid <= '0';
            --invalid <= '1';
            no_input <= true;
        end if;
    end process;

    --process to check bounds and occupation status of line direction
    process(direction_index, opposite, x_next, y_next, no_input, x, y)
        variable x_int, y_int: integer range 0 to 7;
    begin
        x_int := to_integer(unsigned(x));
        y_int := to_integer(unsigned(y));

        --default values
        valid <= '0';
        invalid <= '0';
          valid_internal <= '0';

        if (no_input) then
            null;        -- do nothing

        --check bounds
        elsif (x_next < 0 or x_next > 7 or y_next < 0 or y_next > 7) then
            invalid <= '1';
        --check if occupied
        elsif (connection_register(x_int)(y_int)(direction_index) /= "00" or connection_register(x_next)(y_next)(opposite) /= "00") then
            invalid <= '1';
        --move is valid
        else
            valid <= '1';
                valid_internal <= '1';
        end if;
    end process;


    --update logic
    --updates the grid if there's a valid move
    process(clk, reset)
        variable x_int, y_int: integer range 0 to 7;
    begin
        if (reset = '1') then
            connection_register <= (others => (others => (others => (others => '0'))));
        elsif (clk'event and clk = '1') then
            if (valid_internal = '1') then
                x_int := to_integer(unsigned(x));
                y_int := to_integer(unsigned(y));

                connection_register(x_int)(y_int)(direction_index) <= player;
                connection_register(x_next)(y_next)(opposite) <= player;
            end if;
        end if;
    end process;
end verification;


library ieee;
use ieee.std_logic_1164.all;

entity led_player_indicator is
    port(
            player: in std_logic_vector(1 downto 0);
            leds: out std_logic_vector(17 downto 0)
        );
end led_player_indicator;

architecture player_indicator of led_player_indicator is
begin
    with player select
        leds <= (17 downto 12 => '1', others => '0') when "01",
        (11 downto 6 => '1', others => '0') when "10",
        (5 downto 0 => '1', others => '0') when "11",
        (others => '0') when others;
end player_indicator;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.data_access.all;

entity scoring is
    port(
            clk: in std_logic;
            reset: in std_logic;
            player: in std_logic_vector(1 downto 0);
            winner: out std_logic_vector(1 downto 0) := "00";
            score: out std_logic_vector(8 downto 0);
            x_cord, y_cord: in std_logic_vector(2 downto 0);
            direction: in std_logic_vector(3 downto 0);
            state: in std_logic_vector(1 downto 0);
            full, empty: out std_logic := '0';
            connections: in connection_grid;
            boxes: out box_grid := (others => (others => (others => '0')));
            player_scored: out std_logic := '0'
        );
end scoring;

architecture score_keeper of scoring is
    signal P1_points, P1_points_internal: std_logic_vector(8 downto 0) := (others => '0');
    signal P2_points, P2_points_internal: std_logic_vector(8 downto 0) := (others => '0');
    signal P3_points, P3_points_internal: std_logic_vector(8 downto 0) := (others => '0');
    signal winning_player: std_logic_vector(1 downto 0) := "00";
    signal winning_score: std_logic_vector(8 downto 0) := (others => '0');
    signal current_score: std_logic_vector(8 downto 0) := (others => '0');
    signal filled: std_logic := '0';
    signal x, y : integer range 0 to 7 := 0;
    signal scored : std_logic := '0';
begin
    with reset select
        P1_points <= P1_points_internal when '0',
        (others => '0') when others;
    with reset select
        P2_points <= P2_points_internal when '0',
        (others => '0') when others;
    with reset select
        P3_points <= P3_points_internal when '0',
        (others => '0') when others;
    with winning_player select
        winning_score <= P3_points when "11",
        P2_points when "10",
        P1_points when "01",
        (others => '0') when others;
    with player select
        current_score <= P3_points when "11",
        P2_points when "10",
        P1_points when "01",
        (others => '0') when others;
    winner <= winning_player;
    score <= winning_score when (filled = '1') else current_score;
    x <= to_integer(unsigned(x_cord));
    y <= to_integer(unsigned(y_cord));
    player_scored <= scored;
    process(clk)
        variable points_to_add : integer := 0;
        variable new_score : std_logic_vector(8 downto 0) := "000000000";
        variable box1_x, box1_y, box2_x, box2_y, x_internal, y_internal : integer range 0 to 7 := 0;
        variable direction_internal : integer range -1 to 3 := 0;
    begin
          if (clk'event and clk = '1') then
          if (reset = '1') then
            boxes <= (others => (others => (others => '0')));
            P1_points_internal <= (others => '0');
              P2_points_internal <= (others => '0');
            P3_points_internal <= (others => '0');
            scored <= '0';
            end if;
        if (state = "10" and scored = '0') then
            box1_x := 7;
            box1_y := 7;
            box2_x := 7;
            box2_y := 7;
            x_internal := x;
            y_internal := y;
            points_to_add := 0;
            new_score := (others => '0');
            if (direction = "1000") then direction_internal := LEFT;
            elsif (direction = "0100") then direction_internal := UP;
            elsif (direction = "0010") then direction_internal := RIGHT;
            elsif (direction = "0001") then direction_internal := DOWN;
            else direction_internal := -1;
            end if;
            if (direction_internal = RIGHT) then
                x_internal := x + 1;
                direction_internal := LEFT;
            end if;
            if (direction_internal = LEFT) then
              if (x_internal /= 0 and y_internal /= 0) then
                if (connections(x_internal)(y_internal)(UP) /= "00" and connections(x_internal - 1)(y_internal - 1)(RIGHT) /= "00" and connections(x_internal - 1)(y_internal - 1)(DOWN) /= "00") then
                    box1_x := x_internal - 1;
                    box1_y := y_internal - 1;
                end if;
              end if;
              if (x_internal /= 0 and y_internal /= 7) then
                if (connections(x_internal)(y_internal)(DOWN) /= "00" and connections(x_internal - 1)(y_internal + 1)(RIGHT) /= "00" and connections(x_internal - 1)(y_internal + 1)(UP) /= "00") then
                    box2_x := x_internal - 1;
                    box2_y := y_internal;
                end if;
              end if;
            end if;
            if (direction_internal = DOWN) then
                y_internal := y + 1;
                direction_internal := UP;
            end if;
            if (direction_internal = UP) then
              if (x_internal /= 0 and y_internal /= 0) then
                if (connections(x_internal)(y_internal)(LEFT) /= "00" and connections(x_internal - 1)(y_internal - 1)(RIGHT) /= "00" and connections(x_internal - 1)(y_internal - 1)(DOWN) /= "00") then
                    box1_x := x_internal - 1;
                    box1_y := y_internal - 1;
                end if;
              end if;
              if (x_internal /= 7 and y_internal /= 0) then
                if (connections(x_internal)(y_internal)(RIGHT) /= "00" and connections(x_internal + 1)(y_internal - 1)(LEFT) /= "00" and connections(x_internal + 1)(y_internal - 1)(DOWN) /= "00") then
                    box2_x := x_internal;
                    box2_y := y_internal - 1;
                end if;
              end if;
            end if;
            if (box1_x < 7 and box1_y < 7) then
                boxes(box1_x)(box1_y) <= player;
                points_to_add := points_to_add + 1;
            end if;
            if (box2_x < 7 and box2_y < 7) then
                boxes(box2_x)(box2_y) <= player;
                points_to_add := points_to_add + 1;
            end if;
            if (points_to_add /= 0) then
                scored <= '1';
            else
                scored <= '0';
            end if;
            new_score := std_logic_vector(to_unsigned(to_integer(unsigned(current_score)) + points_to_add, new_score'length));
            case player is
                when "01" =>
                    P1_points_internal <= new_score;
                when "10" =>
                    P2_points_internal <= new_score;
                when "11" =>
                    P3_points_internal <= new_score;
                when others =>
                    null;
            end case;
            if (unsigned(P1_points_internal) + unsigned(P2_points_internal) + unsigned(P3_points_internal) = 49) then
                full <= '1';
                empty <= '0';
            else
                empty <= '1';
                full <= '0';
            end if;
        else
            empty <= '0';
            full <= '0';
            scored <= '0';
        end if;
        end if;
        if (P1_points > P2_points and P1_points > P3_points) then
            winning_player <= "01";
        elsif (P2_points > P1_points and P2_points > P3_points) then
            winning_player <= "10";
        elsif (P3_points > P2_points and P3_points > P1_points) then
            winning_player <= "11";
        else
            winning_player <= "00";
        end if;
    end process;
end score_keeper;

