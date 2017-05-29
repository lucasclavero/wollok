package org.uqbar.project.wollok.typesystem.constraints

import static org.uqbar.project.wollok.typesystem.constraints.ConcreteTypeState.*

enum ConcreteTypeState {
	Pending,
	Ready,
	Error
}

class ConcreteTypeStateExtensions {
	static def join(ConcreteTypeState s1, ConcreteTypeState s2) {
		if (s1 == Ready) s2 else s1
	}
}
