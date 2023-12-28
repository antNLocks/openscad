include <BOSL2/std.scad>;
include <BOSL2/beziers.scad>;


////////////////////////
// Modules definition //
////////////////////////


// Makes a cut along z axis at h_cut height, then linear_extrudes the cut (h height)
module proj_extrude(h_cut, h) {
    translate([0, 0, h_cut]) linear_extrude(h) projection(cut = true) translate([0, 0, -h_cut])  children();
}

// Makes a connected path of sphere (extrusion-like along z axis)
//  height: height of the heightest sphere center
//  bezier_outer_profile: a bezier profile which maps height (0 => bottom, 1 => top) to the distance sphere barycenter - z axis
//  bezier_inner_profile: a bezier profile which maps height (0 => bottom, 1 => top) to the radius of the sphere
//  bezier_angleratio_profile: a bezier profile which maps height (0 => bottom, 1 => top) to the angle ratio (0 => 0°, 1 => 360°) used to rotate the sphere aroud the z axis
//  sphere_fn: Number of polygons used to draw the spheres
//  segments: number of spheres drawn (discretization step)
module _spiral(height, bezier_outer_profile, bezier_inner_profile, bezier_angleratio_profile, sphere_fn, segments) {

    // Calculer les profils de rayon intérieur et extérieur le long de la hauteur
    outer_radii = bezier_points(bezier_outer_profile, [0:1/segments:1]);
    inner_radii = bezier_points(bezier_inner_profile, [0:1/segments:1]);
    angles_ratio = bezier_points(bezier_angleratio_profile, [0:1/segments:1]);

    for (i = [0 : segments - 1]) {
        // Calculer l'angle pour le segment actuel et le suivant
        angle1 = angles_ratio[i][1]*360;
        angle2 = angles_ratio[i+1][1]*360;

        // Rayons extérieurs pour le segment actuel et le suivant
        r_outer1 = outer_radii[i][1];
        r_outer2 = outer_radii[i + 1][1];

        // Rayons intérieurs pour le segment actuel et le suivant
        r_inner1 = inner_radii[i][1];
        r_inner2 = inner_radii[i + 1][1];

        // Points de contrôle pour le segment actuel et le suivant
        p1 = [r_outer1 * cos(angle1), r_outer1 * sin(angle1), height * i / segments];
        p2 = [r_outer2 * cos(angle2), r_outer2 * sin(angle2), height * (i + 1) / segments];

        // Connecter les points avec des formes pour former la spirale
        hull() {
            translate(p1) sphere(r=r_inner1, $fn=sphere_fn);
            translate(p2) sphere(r=r_inner2, $fn=sphere_fn);
        }
    }
}

// Makes a connected path of sphere (extrusion-like along z axis) but cut at a specific height
//  height1: height of the raw _spiral
//  height2: don't keep what's above height2 and under 0
//  the rest => see above
module spiral(height1, height2, bezier_outer_profile, bezier_inner_profile, bezier_angleratio_profile, sphere_fn, segments){
    max_outer_radius = max([for (i= [0: len(bezier_outer_profile)-1]) bezier_outer_profile[i][1]]);
    max_inner_radius = max([for (i= [0: len(bezier_inner_profile)-1]) bezier_inner_profile[i][1]]);

    intersection(){
        _spiral(height1, bezier_outer_profile, bezier_inner_profile, bezier_angleratio_profile, sphere_fn, segments);
        cylinder(h=height2, r=max_outer_radius + max_inner_radius);
    }
}

// Define bezier profile of a single foot and use spiral to render one
//  h: height of the foot
//  the rest => see above
module single_foot(h, sphere_fn, segments){
    bezier_outer_profile = [[0, 10], [0.25, 2.5], [0.75, 5], [1, 27.5]];
    bezier_inner_profile = [[0, 5], [0.25, 1.0], [0.75, 4.0], [1, 12.5]];
    bezier_angleratio_profile = [[0, 0], [0.25, 0.125], [0.75, 0.4], [1, 0.45]];

    render() spiral(h+10, h, bezier_outer_profile, bezier_inner_profile, bezier_angleratio_profile, sphere_fn, segments);
}

// Give glory to the artists
module signature(){
    scale([0.5, 0.5, 0.5])
    translate([0,5,0])
    mirror([1,0,0])
    linear_extrude(1)
    text("aLocks", halign="center", valign="baseline");

    scale([0.5, 0.5, 0.5])
    translate([0,-5,0])
    mirror([1,0,0])
    linear_extrude(1)
    text("GPT-4", halign="center", valign="top");
}

// Foots rotated around the z axis - Support of the statue
//  ALL PARAMETERS ARE GLOBAL FOR CENTRALISTAION => h_foots, num_foots, segments_foots, sphere_fn_foots
module foots(){
    // Créer des pieds en spirale autour d'un cercle
    for (k = [0:num_foots - 1]) {
        rotate([0, 0, k * 360 / num_foots])
            single_foot(h_foots, sphere_fn_foots, segments_foots);
    }

    // Support signé tout en bas
    difference() {
        cylinder(r=r_base_foots, h=h_base_foots, $fn=500);
        signature();
    }
}



// We want to have the exact (convex) profile of what can support the foots - will be used in an intersection with the loss
//  h: the height of extruded profile (should be infinity when we do the intersection)
module foot_plate(h) {
    linear_extrude(h) hull() projection(cut=true) translate([0, 0, -h_foots]) foots();
}

// Draw the bezier patch as a local interpolation of adjacent cubes and fills down to h_min
//  patch: bezier patch
//  h_min: under limit of the hypograph
//  segments: number of cubes used along x axis and along y axis (spatial discretization step)
module hypograph(patch, h_min, segments) {
    tol = 0.2;
    pts = bezier_patch_points(patch, [0:1/segments:1], [0:1/segments:1]);
    for (i = [0:segments - 1]) {
        for (j = [0:segments - 1]) {
            p1 = bezier_patch_points(patch, i/segments, j/segments);
            p2 = bezier_patch_points(patch, (i+1)/segments, j/segments);
            p3 = bezier_patch_points(patch, (i+1)/segments, (j+1)/segments);
            p4 = bezier_patch_points(patch, i/segments, (j+1)/segments);
            hull() {
                translate(p1) rotate([0,180,0]) cube(tol);
                translate([p1[0],p1[1],h_min]) cube(tol);
                translate(p2) rotate([0,180,0]) cube(tol);
                translate([p2[0],p2[1],h_min]) cube(tol);
                translate(p3) rotate([0,180,0]) cube(tol);
                translate([p3[0],p3[1],h_min]) cube(tol);
                translate(p4) rotate([0,180,0]) cube(tol);
                translate([p4[0],p4[1],h_min]) cube(tol);
            };
        }
        
    }
}

// The loss which is adjusted to the support : intersection between hypograph and foot_plate
//  parameters => see above
module loss(patch, segments) {
    intersection() {
        translate([0, 0, h_foots])
        foot_plate(2*(h_loss - h_foots)); // Approximately. To be precise, we would need to calculate the heightest point of the bezier patch but flemme
        hypograph(patch, h_foots, segments);
    }
}

// A beautiful gradient
//  body_w: width of the body
//  body_l: length of the body
//  head_w: width of the head
//  head_l: length of the head
//  h: height
module arrow(body_w, body_l, head_w, head_l, h) {
    linear_extrude(h) {
        translate([-body_w/2, 0]) square([body_w, body_l], center=false);
        translate([0, body_l]) polygon([
            [head_w / 2, 0],
            [0, head_l],
            [-head_w / 2, 0]
        ]);
    };
}

// A beautiful theta
//  body_w: width of the body
//  body_l: length of the body
//  head_w: width of the head
//  head_l: length of the head
//  h: height
module theta(leng, depth, width){
    angle = 75;
    translate([0,0,sin(angle)*leng+width/2]){
        for (m1=[0:1]) { mirror([0,0,m1]){
        for (m2=[0:1]) { mirror([m2,0,0]){
            translate([0,0,-width/2]){
                cube([leng/2+cos(angle)*leng, depth, width/2]);
                translate([leng/2,0,-sin(angle)*leng]) rotate([0,-angle,0]) cube([leng, depth, width]);
                translate([0,0,-sin(angle)*leng]) cube([leng/2, depth, width]);
            }
        }}}}
    }
}

// The statue !
//  h: height indication used to build the bezier patch around this height
//  w: lenght of the square to delimit the patch
module upper_body(h, w) {
    patch = [
        [[-w/2,-w/2,h-2.5], [0,-w/2,h], [w/2,-w/2,h]],
        [[-w/2,0,h], [0,0,h-50], [w/2,0,h]],
        [[-w/2,0,h], [0,0,h+50], [w/2,0,h]],
    
        [[-w/2,w/2,h], [0,w/2,h-25], [w/2,w/2,h]]
    ];
    
    
    pt_grad = bezier_patch_points(patch, 0.5, 0.7);
    n_grad = bezier_patch_normals(patch, 0.5, 0.7);
    grad =  -[n_grad[0],n_grad[1],0]/n_grad[2];
    
    translate([pt_grad[0], pt_grad[1], h_foots]) rotate(acos(-grad[1]/norm(grad)),v=[0,0,1/grad[0]])
    arrow(body_w=3.5, body_l=10, head_w=7.5, head_l=5, h=pt_grad[2] + 1 - h_foots);
    
    translate(pt_grad) rotate(acos(-grad[1]/norm(grad)),v=[0,0,1/grad[0]]) translate([0,-4,0.4]) theta(3.5, 3.5, 1);
    
    render() loss(patch, segments_loss);
}



///////////////////////
// Global parameters //
///////////////////////


// Global geometry parameters
h_foots = 50;
r_base_foots = 20;
h_base_foots = 2.5;
num_foots = 4;
sphere_fn_foots=4;

h_loss = 60;
w_loss = 70;


// Details parameters: high parameters => slow to render
//// For working
segments_foots = 50;
segments_loss = 10;
//// For exporting
// segments_foots = 200;
// segments_loss = 200;



//////////
// Main //
//////////

foots();
//translate([0,0,-h_foots]) // If we want to print just the upper_body: comment the line above and decomment this one
upper_body(h_loss, w_loss);