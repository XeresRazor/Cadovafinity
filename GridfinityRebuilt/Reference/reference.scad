include <../../../Lidded Bins/gridfinity-rebuilt-openscad/gridfinity-rebuilt-utility.scad>

case = "unit_cube";

if (case == "unit_cube") {
    cube([2, 3, 4]);
}
else if (case == "profile_base") {
    linear_extrude(10) profile_base();
}
else if (case == "profile_wall") {
    $dh = 16;
    linear_extrude(10) profile_wall();
}
else if (case == "profile_wall2") {
    $dh = 16;
    linear_extrude(10) profile_wall2();
}
else if (case == "rounded_rectangle") {
    rounded_rectangle(40, 20, 7, 4);
}
else if (case == "block_base_solid") {
    block_base_solid(1, 1, l_grid, 0);
}
else if (case == "block_base_solid_offset") {
    block_base_solid(1, 1, l_grid, -1.5);
}
else if (case == "block_wall_2x1") {
    $dh = 16;
    block_wall(2, 1, l_grid) profile_wall();
}
else if (case == "block_wall_1x2") {
    $dh = 16;
    block_wall(1, 2, l_grid) profile_wall();
}
else if (case == "block_wall_lipless_1x1") {
    $dh = 16;
    block_wall(1, 1, l_grid) profile_wall2();
}
else if (case == "block_bottom_2x1") {
    block_bottom(15.9, 2, 1, l_grid);
}
else if (case == "init_2x1x3") {
    gridfinityInit(2, 1, 16, 0, l_grid, 0) {}
}
else if (case == "init_2x1x3_lipless") {
    gridfinityInit(2, 1, 16, 0, l_grid, 1) {}
}
else if (case == "cut_move_marker") {
    // A unit cube moved to the middle of compartment (1, 0, w=1, h=1) of a 3x2 bin.
    $gxx = 3; $gyy = 2; $dh = 16; $dh0 = 0;
    cut_move(1, 0, 1, 1) translate([-0.5, -0.5, 0]) cube(1);
}
else if (case == "cut_move_marker_dh0") {
    // Same marker with an internal height override, so the z offset uses $dh0.
    $gxx = 3; $gyy = 2; $dh = 16; $dh0 = 20;
    cut_move(1, 0, 1, 1) translate([-0.5, -0.5, 0]) cube(1);
}
else if (case == "pattern_linear") {
    pattern_linear(3, 2, 10, 7) translate([1, 2, 0]) cube([2, 3, 4]);
}
else if (case == "hole_style1") { block_base_hole(1, 0); }
else if (case == "hole_style2") { block_base_hole(2, 0); }
else if (case == "hole_style3") { block_base_hole(3, 0); }
else if (case == "hole_style2_off") { block_base_hole(2, -0.5); }
else if (case == "hole_refined") { refined_hole(); }
else if (case == "base_1x1_style0")        { gridfinityBase(1, 1, l_grid, 0, 0, 0, 0, true, false); }
else if (case == "base_2x1_style1")        { gridfinityBase(2, 1, l_grid, 0, 0, 1, 0, true, false); }
else if (case == "base_2x2_style2")        { gridfinityBase(2, 2, l_grid, 0, 0, 2, 0, true, false); }
else if (case == "base_1x1_style3")        { gridfinityBase(1, 1, l_grid, 0, 0, 3, 0, true, false); }
else if (case == "base_1x1_style4")        { gridfinityBase(1, 1, l_grid, 0, 0, 4, 0, true, false); }
else if (case == "base_2x2_corners")       { gridfinityBase(2, 2, l_grid, 0, 0, 2, 0, true, true); }
else if (case == "base_2x2_baseplate")     { gridfinityBase(2, 2, l_grid, 1, 1, 0, 0.5, false, false); }
else if (case == "base_1_5x1_half")        { gridfinityBase(1.5, 1, l_grid, 0, 0, 0, 0, true, false); }
else if (case == "base_1x1_offset_neg")    { gridfinityBase(1, 1, l_grid, 0, 0, 2, -1.2, true, false); }
// CASES: later tasks append `else if (case == "...") { ... }` blocks above this line.
