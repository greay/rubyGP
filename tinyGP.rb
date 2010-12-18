require "benchmark"

ADD = 110
SUB = 111
MUL = 112
DIV = 113
FSET_START = ADD
FSET_END = DIV

MAX_LEN = 10000
POPSIZE = 10000
DEPTH = 5
GENERATIONS = 100
TSIZE = 2

PMUT_PER_NODE = 0.05
CROSSOVER_PROB = 0.9

class TinyGP
	def initialize(fname, s)
		@buffer = Array.new(MAX_LEN, 0)
		@fbestpop = 0.0
		@favgpop = 0.0
		@pc = 0

		@fitness = Array.new POPSIZE
		@seed = s
		if @seed >= 0 then
			srand @seed
		end
		self.setup_fitness fname

		@x = []
		FSET_START.times do
			@x.push((@maxrandom - @minrandom) * rand + @minrandom)
		end
		@pop = self.create_random_pop(POPSIZE, DEPTH, @fitness)
	end
	
	def run
		primitive = @program[@pc += 1]
		if primitive < FSET_START then
			return @x[primitive]
		end
		
		case primitive
		when ADD
			self.run + self.run
		when SUB
			self.run - self.run
		when MUL
			self.run * self.run
		when DIV
			num = self.run
			den = self.run
			if den.abs <= 0.001 then
				num
			else
				num / den
			end
		else # should never get here
			0.0
		end
	end
	
	def traverse(buffer, buffercount)
		if buffer[buffercount] < FSET_START then
			return buffercount += 1
		end
		
		case buffer[buffercount]
		when ADD..DIV
			self.traverse(buffer, self.traverse(buffer, buffercount += 1))
		else # should never get here
			0
		end
	end
	
	def setup_fitness(fname)
		File::open(fname, "r") do |f|
			line = f.gets.split
			@varnumber = line[0].to_i
			@randomnumber = line[1].to_i
			@minrandom = line[2].to_f
			@maxrandom = line[3].to_f
			@fitnesscases = line[4].to_i

			# targets = new double[fitnesscases][varnumber+1];
			@targets = Array.new(@fitnesscases, [])
			
			if @varnumber + @randomnumber >= FSET_START then
				puts "too many variables and constants"
			end
			
			@fitnesscases.times do |i|
				line = f.gets.split
				(@varnumber + 1).times do |j|
					@targets[i][j] = line[j].to_f
				end
			end
		end
	end
	
	def fitness_function(prog)
		len = self.traverse(prog, 0)
		fit = 0.0
		@fitnesscases.times do |i|
			@varnumber.times do |j|
				@x[j] = @targets[i][j]
			end
			@program = prog
			@pc = 0
			result = self.run
			fit += (result - @targets[i][@varnumber]).abs
		end
		-fit
	end
	
	def grow(buffer, pos, max, depth)
		prim = rand(2)
		
		if (pos >= max) then
			return -1
		end
		
		if (pos == 0) then
			prim = 1
		end
		
		if prim == 0 || depth == 0 then
			prim = rand(@varnumber + @randomnumber)
			buffer[pos] = prim
			return pos + 1
		else
			prim = rand(FSET_END - FSET_START + 1) + FSET_START
			case prim
			when ADD..DIV
				buffer[pos] = prim
				one_child = self.grow(buffer, pos, max, depth - 1)
				if (one_child < 0) then
					return -1
				end
				return grow(buffer, one_child, max, depth - 1)
			end
		end
		0 # should never get here
	end
	
	def print_indiv(buffer, buffercounter)
		a1 = 0
		if buffer[buffercounter] < FSET_START then
			if buffer[buffercounter] < @varnumber then
				print "X" + (buffer[buffercounter] + 1).to_s + " "
			else
				print @x[buffer[buffercounter]].to_s
			end
			return (buffercounter += 1)
		end
		case buffer[buffercounter]
		when ADD
			print "("
			a1 = self.print_indiv(buffer, buffercounter += 1)
			print " + "
		when SUB
			print "("
			a1 = self.print_indiv(buffer, buffercounter += 1)
			print " - "
		when MUL
			print "("
			a1 = self.print_indiv(buffer, buffercounter += 1)
			print " * "
		when DIV
			print "("
			a1 = self.print_indiv(buffer, buffercounter += 1)
			print " / "
		end
		a2 = self.print_indiv(buffer, a1)
		print ")"
		return a2
	end
	
	def create_random_indiv(depth)
		len = self.grow(@buffer, 0, MAX_LEN, depth)
		while len < 0 do
			len = grow(@buffer, 0, MAX_LEN, depth)
		end
		ind = @buffer.slice(0, len)
	end
	
	def create_random_pop(n, depth, fitness)
		pop = []
		n.times do |n|
			indiv = self.create_random_indiv depth
			pop.push indiv
			@fitness.push(self.fitness_function indiv)
		end
		pop
	end
	
	def stats(fitness, pop, gen)
		best = rand(POPSIZE)
		node_count = 0
		@fbestpop = @fitness[best]
		@favgpop = 0.0
		
		POPSIZE.times do |i|
			node_count += self.traverse(pop[i], 0)
			favgpop = @fitness[i]
			if @fitness[i] > @fbestpop then
				best = i
				@fbestpop = @fitness[i]
			end
		end
		avg_len = node_count / POPSIZE
		@favgpop /= POPSIZE
		puts "Generation=#{gen} Avg Fitness=#{-@favgpop} Best Fitness=#{-@fbestpop} Avg Size=#{avg_len}"
		print "Best Individual: "
		self.print_indiv(pop[best], 0)
		print "\n"
	end
	
	def tournament(fitness, tsize)
		best = rand(POPSIZE)
		fbest = -1.0e34
		
		tsize.times do |i|
			competitor = rand(POPSIZE)
			if @fitness[competitor] > fbest then
				fbest = @fitness[competitor]
				best = competitor
			end
		end
		best
	end
	
	def negative_tournament(fitness, tsize)
		worst = rand(POPSIZE)
		fworst = 1e34
		
		tsize.times do |i|
			competitor = rand(POPSIZE)
			if @fitness[competitor] < fworst then
				fworst = @fitness[competitor]
				worst = competitor
			end
		end
		worst
	end
	
	def crossover(parent1, parent2)
		len1 = self.traverse(parent1, 0)
		len2 = self.traverse(parent2, 0)
		
		xo1start = rand(len1)
		xo1end = self.traverse(parent1, xo1start)
		
		xo2start = rand(len2)
		xo2end = self.traverse(parent2, xo2start)
		
		lenoff = xo1start + (xo2end - xo2start) + (len1 - xo1end)
		
		offspring = parent1.dup[0..xo1start]
		offspring[xo1start..(xo2end - xo2start)] = parent2[xo2start..xo2end]
		offspring[xo1start..(len1 - xo1end)] = parent1[xo1end..len1]
		offspring
	end
	
	def mutation(parent, pmut)
		len = self.traverse(parent, 0)
		mutsite = 0
		parentcopy = Array.new len
		
		parentcopy = parent.dup
		len.times do |i|
			if rand < pmut then
				mutsite = i
				if parentcopy[mutsite] < FSET_START then
					parentcopy[mutsite] = rand(varnumber + randomnumber)
				else
					case parentcopy[mutsite]
					when ADD..DIV
						parentcopy[mutsite] = rand(FSET_END - FSET_START + 1) + FSET_START
					end
				end
			end
		end
		parentcopy
	end
	
	def print_parms
		puts "-- TINY GP (ruby version) --"
		puts "SEED=#{@seed}\nMAX_LEN=#{MAX_LEN}"
		puts "POPSIZE=#{POPSIZE}\nDEPTH=#{DEPTH}"
		puts "CROSSOVER_PROB=#{CROSSOVER_PROB}"
		puts "PMUT_PER_NODE=#{PMUT_PER_NODE}"
		puts "MIN_RANDOM=#{@minrandom}\nMAX_RANDOM=#{@maxrandom}"
		puts "GENERATIONS=#{GENERATIONS}"
		puts "TSIZE=#{TSIZE}"
		puts "----------------------------------"
	end
	
	def evolve
		newind = []
		self.print_parms
		self.stats(@fitness, @pop, 0)
		1..GENERATIONS do |gen|
			if @fbestpop > -1e-5 then
				puts "PROBLEM SOLVED"
				return nil
			end
			POPSIZE.times do |indivs|
				if rand < CROSSOVER_PROB then
					parent1 = self.tournament(@fitness, TSIZE)
					parent2 = self.tournament(@fitness, TSIZE)
					newind = self.crossover(@pop[parent1], @pop[parent2])
				else
					parent = self.tournament(@fitness, TSIZE)
					newind = self.mutation(@pop[parent], PMUT_PER_NODE)
				end
				newfit = self.fitness_function(newind)
				offspring = self.negative_tournament(@fitness, TSIZE)
				@pop[offspring] = newind
				@fitness[offspring] = newfit
			end
			self.stats(@fitness, @pop, gen)
		end
		
		puts "PROBLEM *NOT* SOLVED"
		return true
	end
end

# and run...

Benchmark.bm(15) do |x|
	g = TinyGP.new("sin-data.txt", 23)
end
