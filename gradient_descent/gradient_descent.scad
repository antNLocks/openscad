include <BOSL2/std.scad>;
include <BOSL2/beziers.scad>;

//$fn=100;

module proj_extrude(h_cut, h) {
    translate([0, 0, h_cut]) linear_extrude(h) projection(cut = true) translate([0, 0, -h_cut])  children();
}

module _spiral(height, bezier_outer_profile, bezier_inner_profile, bezier_angleratio_profile, segments) {

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
            translate(p1) sphere(r=r_inner1, $fn=4);
            translate(p2) sphere(r=r_inner2, $fn=4);
        }
    }
}


module spiral(height1, height2, bezier_outer_profile, bezier_inner_profile, bezier_angleratio_profile, segments){
    max_outer_radius = max([for (i= [0: len(bezier_outer_profile)-1]) bezier_outer_profile[i][1]]);
    max_inner_radius = max([for (i= [0: len(bezier_inner_profile)-1]) bezier_inner_profile[i][1]]);

    intersection(){
        _spiral(height1, bezier_outer_profile, bezier_inner_profile, bezier_angleratio_profile, segments);
        cylinder(h=height2, r=max_outer_radius + max_inner_radius);
    }
}


module single_foot(h){
    bezier_outer_profile = [[0, 10], [0.25, 2.5], [0.75, 5], [1, 27.5]];
    bezier_inner_profile = [[0, 5], [0.25, 1.0], [0.75, 4.0], [1, 12.5]];
    bezier_angleratio_profile = [[0, 0], [0.25, 0.125], [0.75, 0.4], [1, 0.45]];

    spiral(h+10, h, bezier_outer_profile, bezier_inner_profile, bezier_angleratio_profile, 50);
}

module foots(h, h_bridge=0){
    num_foot = 4;
    // Créer des pieds en spirale autour d'un cercle
    for (k = [0:num_foot - 1]) {
        rotate([0, 0, k * 360/num_foot])
            single_foot(h);
    }
    // Support tout en bas
    cylinder(r=20, h=2.5);
    
    proj_extrude(h, h_bridge)
    hull() {
        rotate([0, 0, 2 * 360/num_foot])
        single_foot(h);
        rotate([0, 0, 3 * 360/num_foot])
        single_foot(h);
    };
    proj_extrude(h, h_bridge)
    hull() {
        rotate([0, 0, 0 * 360/num_foot])
        single_foot(h);
        rotate([0, 0, 1 * 360/num_foot])
        single_foot(h);
    };
}

module foot_plate(h_foot, h) {
    translate([0,0,-h_foot]) proj_extrude(h_foot, h) hull() foots(h_foot);
}


module hypograph(patch, h_min, segments=7) {
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

module loss(patch, h_foot, h_bridge, segments=7) {
    intersection() {
        translate([0,0,h_foot+h_bridge])
        foot_plate(h_foot, 20);
        hypograph(patch, h_foot+h_bridge, segments);
    }
}

module arrow(base_w, base_h, head_w, head_h, h1, h2) {
    translate([0,0,h1])
    linear_extrude(h2-h1) {
        translate([-base_w/2, 0]) square([base_w, base_h], center=false);
        translate([0, base_h]) polygon([
            [head_w / 2, 0],
            [0, head_h],
            [-head_w / 2, 0]
        ]);
    };
}

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


module upper_body(h, w, h_foot, h_bridge) {

    patch = [
        [[-w/2,-w/2,h-2.5], [0,-w/2,h], [w/2,-w/2,h]],
        [[-w/2,0,h], [0,0,h-50], [w/2,0,h]],
        [[-w/2,0,h], [0,0,h+50], [w/2,0,h]],
    
        [[-w/2,w/2,h], [0,w/2,h-25], [w/2,w/2,h]]
    ];
    
    
    pt_grad = bezier_patch_points(patch, 0.5, 0.7);
    n_grad = bezier_patch_normals(patch, 0.5, 0.7);
    grad =  -[n_grad[0],n_grad[1],0]/n_grad[2];
    
    translate([pt_grad[0],pt_grad[1],0]) rotate(acos(-grad[1]/norm(grad)),v=[0,0,1/grad[0]])
    arrow(base_w=3.5, base_h=10, head_w=7.5, head_h=5, h1=h_foot+h_bridge, h2=pt_grad[2]+1);
    
    translate(pt_grad) rotate(acos(-grad[1]/norm(grad)),v=[0,0,1/grad[0]]) translate([0,-4,0.4]) theta(3.5, 3.5, 1);
    
    loss(patch, h_foot, h_bridge, segments_loss);
}

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

h_foot = 50;
h_bridge=0;


render() difference(){
    foots(h_foot, h_bridge);
    signature();
};

h = 60;
w = 70;
//segments_loss = 100;
segments_loss = 5;

//translate([0,0,-h_foot]) 
render() upper_body(h, w, h_foot, h_bridge);

