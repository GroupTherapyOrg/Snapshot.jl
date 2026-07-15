module SnapshotPoisonFixture

import Base: length
import Statistics: mean
export poison_marker, length, mean, clash

poison_marker(x) = x
clash(x) = x + 10

end
