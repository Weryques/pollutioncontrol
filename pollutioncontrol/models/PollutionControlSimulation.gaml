/**
* Name: PollutionControlSimulation
* Author: 
* Description: 
* Tags: 
*/

model PollutionControlSimulation

/* Insert your model definition here */

global {   
	file shape_file_roads  <- file("../includes/roads.shp") ;
	file shape_file_nodes  <- file("../includes/nodes.shp");
	geometry shape <- envelope(shape_file_roads);
	
	graph road_network;
	int nb_car <- 100;
	float min_speed <- 30 #km /#h;
	
	init {  
		create semaphore from: shape_file_nodes with:[is_traffic_signal::(read("type") = "traffic_signals")];
		ask semaphore where each.is_traffic_signal {
			stop << flip(0.5) ? roads_in : [] ;
		}
		
		create road from: shape_file_roads with:[lanes::int(read("lanes")), maxspeed::float(read("maxspeed")) °km/°h, oneway::string(read("oneway"))] {
			geom_display <- (shape + (2.5 * lanes));
			switch oneway {
				match "no" {
					create road {
						lanes <- myself.lanes;
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- myself.maxspeed;
						geom_display  <- myself.geom_display;
						linked_road <- myself;
						myself.linked_road <- self;
					}
				}
				match "-1" {
					shape <- polyline(reverse(shape.points));
				}
			}
		}	
		
		map general_speed_map <- road as_map(each::( each.shape.perimeter / (each.maxspeed) ));
		road_network <- (as_driving_graph(road, semaphore)) with_weights general_speed_map;
		
		create car number: nb_car { 
			speed <- min_speed;
			vehicle_length <- 3.0 #m;
			right_side_driving <- true;
			proba_lane_change_up <- 0.1 + (rnd(500) / 500);
			proba_lane_change_down <- 0.5+ (rnd(500) / 500);
			location <- one_of(semaphore where empty(each.stop)).location;
			security_distance_coeff <- 2 * (1.5 - rnd(1000) / 1000);  
			proba_respect_priorities <- 1.0 - rnd(200/1000);
			proba_respect_stops <- [1.0 - rnd(2) / 1000];
			proba_block_node <- rnd(3) / 1000;
			proba_use_linked_road <- 0.0;
			//max_acceleration <- 0.5 + rnd(500) / 1000;
			speed_coeff <- 1.2 - (rnd(400) / 1000);
		}	
	}
	
} 
species semaphore skills: [skill_road_node] {
	bool is_traffic_signal;
	int time_to_change <- 100;
	int counter <- rnd (time_to_change) ;
	
	reflex dynamic when: is_traffic_signal {
		counter <- counter + 1;
		if (counter >= time_to_change) { 
			counter <- 0;
			stop[0] <- empty (stop[0]) ? roads_in : [] ;
		} 
	}
	
	aspect geom3D {
		if (is_traffic_signal) {	
			draw box(4,4,10) color:rgb("black");
			draw sphere(10) at: {location.x,location.y,12} color: empty (stop[0]) ? #green : #red;
		}
	}
}

species road skills: [skill_road] { 
	string oneway;
	geometry geom_display;
	aspect geom {    
		draw geom_display border:  #black  color: #black;
	}  
}
	
species car skills: [advanced_driving] { 
	rgb color <- rnd_color(255);
	
	float pollution_coeff <- 1.6 max: 170.0;
	
	
	reflex time_to_go when: final_target = nil {
		current_path <- compute_path(graph: road_network, target: one_of(semaphore));
	}
	reflex move when: final_target != nil {
		do drive;
		
	}
	aspect car3D {
		if (current_road) != nil {
			point loc <- calcul_loc();
			draw box(vehicle_length, 4,4) at: loc rotate:  heading color: color;
			draw triangle(3.0) depth: 1.5 at: loc rotate:  heading + 90 color: color;	
		}
	} 
	
	point calcul_loc {
		float val <- (road(current_road).lanes - current_lane) + 0.5;
		val <- on_linked_road ? val * - 1 : val;
		if (val = 0) {
			return location; 
		} else {
			return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
		}
	}
} 

experiment pollution_control_simulation type: gui {
	parameter "Shapefile das vias:" var: shape_file_roads category: "GIS" ;
	parameter "Shapefile dos semáforos:" var: shape_file_nodes category: "GIS" ;
	
	parameter "Número de carros em transito:" var: nb_car category: "Carros";
	parameter "Velocidade minima de todos os carros:" var: min_speed category: "Carros" min: 30 #km /#h;
	
	output {
		display city_display type: opengl{
			species road aspect: geom refresh: false;
			species semaphore aspect: geom3D transparency: 0.1;
			species car aspect: car3D;
		}
		
		display chart_display{
			chart "Níveis de poluição" type: series size:{1, 0.5} position:{0,0}{
				
			}
		}
	}
}