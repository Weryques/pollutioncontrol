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
	int nb_car <- 1836;
	float speedm <- 30 °km/°h;
	float pollution_coeff <- 0.0;
	float pollution_stoped <- 0.0;
	float pollution <- 1.6;
	float kilo <- 0.0;
	float mean_speed <- 0.0;
	float speedex <- 0.0;
	
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
			speed <- speedm;
			real_speed <- 30 °km/°h;
			vehicle_length <- 3.0 °m;
			right_side_driving <- true;
			proba_lane_change_up <- 0.1 + (rnd(500) / 500);
			proba_lane_change_down <- 0.5+ (rnd(500) / 500);
			location <- one_of(semaphore where empty(each.stop)).location;
			security_distance_coeff <- 2 * (1.5 - rnd(1000) / 1000);  
			proba_respect_priorities <- 1.0 - rnd(200/1000);
			proba_respect_stops <- [1.0 - rnd(2) / 1000];
			proba_block_node <- rnd(3) / 1000;
			proba_use_linked_road <- 0.0;
			max_acceleration <- 0.5 + rnd(500) / 1000;
			speed_coeff <- 1.2 - (rnd(400) / 1000);
		}
	}
	
	reflex end when: cycle >= 210 {
		do pause;
	}
} 
species semaphore skills: [skill_road_node] {
	bool is_traffic_signal;
	int time_to_change <- 100;
	int counter <- rnd (time_to_change) ;
	
	reflex dynamic when: is_traffic_signal {
		counter <- counter + 1;
		if (counter >= time_to_change) { 
			counter <- 0; //contador é zerado
			stop[0] <- empty (stop[0]) ? roads_in : [] ; //semáforo fecha
		} 
	}
	
	aspect geom3D {
		if (is_traffic_signal) {	
			draw box(1,1,10) color:rgb("black");
			draw sphere(5) at: {location.x,location.y,12} color: empty (stop[0]) ? #green : #red;
		}
	}
}

species road skills: [skill_road] { 
	string oneway;
	geometry geom_display;
	aspect geom {    
		draw geom_display border:  #gray  color: #gray;
	}  
}
	
species car skills: [advanced_driving] { 
	rgb color <- rnd_color(255);
	
	reflex time_to_go when: final_target = nil {
		current_path <- compute_path(graph: road_network, target: one_of(semaphore));
	}

	reflex move when: final_target != nil {
		do drive;
		
		list segments <- current_path.segments;
		loop line over: segments{
			float distance <- line.perimeter;
			pollution_coeff <- pollution_coeff + ((pollution * distance) / 1000000) / 100;
			pollution_stoped <- pollution_stoped + (rnd(0.1, 0.8) / 100000) / 100; //escala de grama para kg
			kilo <- kilo + (distance / 100000);
		}
		mean_speed <- real_speed * 10;
		speedex <- min([max_speed, min([real_speed + max_acceleration, max_speed * speed_coeff])]) * 10;
	}
	
	aspect car3D {
		if (current_road) != nil {
			point loc <- calcul_loc();
			draw box(vehicle_length, 1,1) at: loc rotate:  heading color: color;
			draw triangle(0.5) depth: 1.5 at: loc rotate:  heading + 90 color: color;	
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
	
	parameter "Número de carros:" var: nb_car category: "Carros" min: 1836;
	parameter "Velocidade minima m/s:" var: speedm category: "Carros";
	
	float minimum_cycle_duration <- 0.2;
	
	output {
		display city_display type: opengl{
			species road aspect: geom refresh: false;
			species semaphore aspect: geom3D;
			species car aspect: car3D;
		}
		
		display chart_pollution{
			chart "Quilos de Poluicão de todos os carros" type: histogram size:{1, 0.5} position:{0,0}{
				data "Poluição dirigindo" value: pollution_coeff color: #red marker: false;
				data "Poluição parado" value: pollution_stoped color: #blue marker: false;
				data "Maximo de poluição" value: 50 color: #gray marker: false;
			}
			chart "Distância percorrida de todos os carros" type: series size:{1, 0.5} position:{0,0.5}{
				data "Km percorridos" value: kilo color: #blue marker: false;
				data "Maxima" value: 5000 color: #black marker: false;
			}
		}
		display chart_speed{
			chart "Speed" type: series size:{1, 0.5} position:{0,0}{
				data "speed" value: mean_speed color:#gold marker: false;
				data "speedex" value: speedex color:#goldenrod marker: false;
				data "max speed" value: 120 color:#darkorange marker: false;
			}
		}
	}
}