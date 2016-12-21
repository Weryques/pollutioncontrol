/**
* Name: PollutionControlSimulation
* Author: 
* Description: 
* Tags: 
*/

model PollutionControlSimulation

/*
 * 1 Agentes: 
 * 
 * Veículos:
 * Objetivo: Percorrer as rodovias da cidade, Emitir poluição no Ar.
 * Capacidades - Percepção+Ação: Perceber outros veículos e desviar deles; Perceber sentido correto e velocidade máxima das vias;
 * 
 * 2 Ambiente:
 * 
 * Variáveis: Velocidade das vias da cidade, quantidade veiculos.
 * 
 * 3 Comunicação: há apenas um tipo de agente, sem necessidade de comunicação.
 * 
 * 4 O modelo tem o objetivo de: Representar um ambiente onde temos 1 tipo de agente poluente e como as alterações no agente influenciam sua capacidade de poluir.
 */

global {   
	file shape_file_roads  <- file("../includes/roads.shp") ;
	file shape_file_nodes  <- file("../includes/nodes.shp");
	geometry shape <- envelope(shape_file_roads);
	
	graph road_network;
	int nb_car <- 2409;
	float speedm <- 30 °km/°h;
	float pollution_coeff <- 0.0;
	float pollution_stoped <- 0.0;
	float kilo <- 0.0;
	float speedex <- 0.0;
	float pollution_filter <- 0.0;
	
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
						lanes <- myself.lanes; // Adiciona faixas do shapefile
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- myself.maxspeed; // Adiciona a velocidade máxima do shapefile
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
			real_speed <- speedm;
			vehicle_length <- 3.0 °m;
			right_side_driving <- true; // Direção do lado direito
			proba_lane_change_up <- 0.1 + (rnd(500) / 500);
			proba_lane_change_down <- 0.5+ (rnd(500) / 500);
			location <- one_of(semaphore where empty(each.stop)).location;
			security_distance_coeff <- 2 * (1.5 - rnd(1000) / 1000); // Distância segura do veiculo da frente
			proba_respect_priorities <- 1.0 - rnd(200/1000); // Probabilidade de respeitar prioridades
			proba_respect_stops <- [1.0 - rnd(2) / 1000]; // Probabilidade respeitar Pares
			proba_block_node <- rnd(3) / 1000;
			proba_use_linked_road <- 0.0;
			max_acceleration <- 0.5 + rnd(500) / 1000;
			speed_coeff <- 1.2 - (rnd(400) / 1000);
		}
	}
	
	reflex end when: cycle = 210 {
		do pause;
	}
} 
species semaphore skills: [skill_road_node] {
	bool is_traffic_signal;
	int time_to_change <- 100; // segundos
	int counter <- rnd (time_to_change) ; //0 a 100s
	
	reflex dynamic when: is_traffic_signal {
		counter <- counter + 1;
		if (counter >= time_to_change) { 
			counter <- 0; // Contador é zerado
			stop[0] <- empty (stop[0]) ? roads_in : [];
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
		draw geom_display color: #gray;
	}  
}
	
species car skills: [advanced_driving] { 
	rgb color <- rnd_color(255);
	
	reflex time_to_go when: final_target = nil {
		current_path <- compute_path(graph: road_network, target: one_of(semaphore));
	}

	reflex move when: final_target != nil {
		do drive; // Leva o veiculo até o seu alvo final, o semáforo
		
		list segments <- current_path.segments;
		loop line over: segments{
			float distance <- line.perimeter;
			
			if(speedex >= 10.0 and speedex <= 50.0){
				// Calculo de toda a poluição gerada
				pollution_coeff <- pollution_coeff + (((rnd(1.3, 1.5) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
				// Calculo da poluição com filtro
				pollution_filter <- pollution_filter + (((rnd(0.2, 0.244) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
			}
			else if(speedex > 50.0 and speedex <= 70.0){
				pollution_coeff <- pollution_coeff + (((rnd(1.51, 1.7) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
				pollution_filter <- pollution_filter + (((rnd(0.2, 0.224) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
			}
			else if(speedex > 70.0 and speedex <= 90.0){
				pollution_coeff <- pollution_coeff + (((rnd(1.71, 1.9) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
				pollution_filter <- pollution_filter + (((rnd(0.2, 0.224) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
			}
			else if(speedex > 90.0){
				pollution_coeff <- pollution_coeff + (((rnd(1.91, 2.0) * distance) / 1000000) / 100); // As divisões são para se adequa à escala do gráfico
				pollution_filter <- pollution_filter + (((rnd(0.2, 0.224) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
			}
			else{
				// Calculo da poluição do carro parado.
				pollution_stoped <- pollution_stoped + (rnd(0.1, 0.8) / 100000) / 100; // As divisões são para se adequar à escala do gráfico
			}			
			// Soma de todas as distânias percorridas
			kilo <- kilo + (distance / 100000); // A divisão é para se adequar à escala do gráfico	
			
		}
		
		// A velocidade do carro é influenciada pela velocidade máxima, pela velocidade real, pela aceleração máxima e pelo coeficiente de velocidade.
		speedex <- min([max_speed, min([real_speed + max_acceleration, max_speed * speed_coeff])]) * 10; // A multiplicação é para se adequar à escala do gráfico
	}
	
	aspect car3D {
		if (current_road) != nil {
			point loc <- calcul_loc();
			// O carro é desenhado na coordenada retornada 'at: loc'
			draw box(vehicle_length, 1,1) at: loc rotate:  heading color: color;
			draw triangle(0.5) depth: 1.5 at: loc rotate:  heading + 90 color: color;	
		}
	} 
	
	// Calcula a localização e retorna um point com as coordenadas x e y:
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
	parameter "Número de carros:" var: nb_car category: "Carros" min: 2409;
	parameter "Velocidade mínima m/s:" var: speedm category: "Carros";
	
	float minimum_cycle_duration <- 0.2;
	
	output {
		display city_display type: opengl{
			species road aspect: geom refresh: false;
			species semaphore aspect: geom3D;
			species car aspect: car3D;
		}
		
		display chart_pollution{
			chart "Quilos de poluicão de todos os carros" type: histogram size:{0.5, 0.5} position:{0,0}{
				data "Poluição dirigindo" value: pollution_coeff color: #red marker: false;
				data "Poluição parado sem filtro" value: pollution_stoped color: #blue marker: false;
				data "Poluição com filtro" value: pollution_filter color: #darkslategray marker: false;
				data "Máximo de poluição" value: 20 color: #gray marker: false;
			}
			chart "Distância percorrida de todos os carros" type: series size:{0.5, 0.5} position:{0.5,0}{
				data "Km percorridos" value: kilo color: #blue marker: false;
				data "Distância Máxima" value: 5000 color: #black marker: false;
			}
			chart "Velocidade" type: series size:{1, 0.5} position:{0,0.5}{
				data "Velocidade" value: speedex color:#goldenrod marker: false;
				data "Velocidade Máxima" value: 120 color:#darkorange marker: false;
			}
		}
	}
}