tool
extends Line2D

export(Curve2D) var curve = null setget set_curve
export(float, 0, 1000000, 0.1) var Bake_Interval = 5 setget set_bake_interval
export(float, 0, 100, 0.01) var Softness = 1
export(float, 0, 1, 0.01) var Bias = 0
export(float, 0, 100, 0.01) var Mass = 0.1
export(float, 0, 100, 0.01) var Bounce = 1
export(bool) var Can_sleep = true
export(float, 0, 100, 0.1) var Linear_dumping = -1
export(float, 0, 100, 0.1) var Angular_dumping = -1


export(NodePath) var start_node = null
export var pined_points = [0]

var rigid_bodies = []

var uvs = PoolVector2Array([Vector2(1, 1), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)])

func set_curve(value):
    curve = value
    pined_points = [0]
    update()

func get_curve():
	return curve

func set_bake_interval(value):
    Bake_Interval = value;
    curve.set_bake_interval(Bake_Interval)
    update()

func get_baked_points():
    return curve.get_baked_points()

func get_baked_length():
    return curve.get_baked_length()

func get_point_count():
    return curve.get_point_count()

func add_point(pos, in_pos, out_pos, index):
    curve.add_point(pos, in_pos, out_pos, index)
    for i in range(pined_points.size()):
        if(pined_points[i] >= index):
            pined_points[i] = pined_points[i] + 1


func remove_point(index):
    curve.remove_point(index)
    pined_points.erase(index)
    for i in range(pined_points.size()):
        if(pined_points[i] >= index):
            pined_points[i] = pined_points[i] - 1

func set_point_pos(index, pos):
    curve.set_point_position(index, pos)

func set_point_in(index, pos):
    curve.set_point_in(index, pos)

func set_point_out(index, pos):
    curve.set_point_out(index, pos)

func get_point_pos(index):
    return curve.get_point_position(index)

func get_point_in(index):
    return curve.get_point_in(index)

func get_point_out(index):
    return curve.get_point_out(index)

func _enter_tree(value):
    pass

func add_pin_point(index):
    if(!is_point_pined(index)):
        pined_points.push_back(index)

func remove_pin_point(index):
    pined_points.erase(index)

func is_point_pined(index):
    return pined_points.has(index)

func _ready():
    if(curve == null):
        curve = load("addons/Rope/Curve_default.tres")
        curve = curve.duplicate()
    curve.connect("changed", self, "update")

    if(!Engine.editor_hint):
        ingame_ready()

func ingame_ready():
    var array = curve.get_baked_points()
    var pined_baked_points = get_baked_pin_points()
    for i in range(0, array.size() - 1):
        var current = array[i]
        var next = array[i + 1]
        var body = RigidBody2D.new()
        var shape = RectangleShape2D.new()
        shape.set_extents(Vector2(width / 2, (next - current).length() * 0.9))
        var bso = body.create_shape_owner(shape)
        body.shape_owner_add_shape(bso, shape)
        body.set_rotation((next - current).angle())
        set_body_params(body)
        body.set_position(current)
        add_child(body)
        if(rigid_bodies.size() > 0):
            var lastBody = rigid_bodies[rigid_bodies.size() - 1]
            add_pin_joint(lastBody.get_path(), body.get_path(), body.get_position())
        elif start_node:
            var _start_node = get_node(start_node)
            add_pin_joint(_start_node.get_path(), body.get_path(), body.get_position())

        if(pined_baked_points.has(i)):
            add_pin_joint(self.get_path(), body.get_path(), body.get_position())
        rigid_bodies.push_back(body)

    if(pined_baked_points.has(array.size() - 1)):
        var body = rigid_bodies[rigid_bodies.size() - 1]
        var pos = get_end_pos(body)
        add_pin_joint(self.get_path(), body.get_path(), pos)
    set_process(true)

func set_body_params(body):
    body.collision_layer = 0
    body.collision_mask = 0
    body.set_mass(Mass)
    body.set_bounce(Bounce)
    body.set_can_sleep(Can_sleep)
    body.set_linear_damp(Linear_dumping)
    body.set_angular_damp(Angular_dumping)
    body.mode = RigidBody2D.MODE_RIGID

func add_pin_joint(node_a, node_b, _position):
    var pin = PinJoint2D.new()
    pin.set_node_a(node_a)
    pin.set_node_b(node_b)
    pin.set_position(_position)
    pin.set_softness(Softness)
    pin.bias = Bias
    pin.disable_collision = true
    add_child(pin)
    return pin

func get_baked_pin_points():
    var array = curve.get_baked_points()
    var pined_baked_points = []
    for i in pined_points:
        var closest_length = (array[0] - curve.get_point_position(i)).length()
        var closest_index = 0;
        for j in range(1, array.size()):
            var currentLength = (array[j] - curve.get_point_position(i)).length()
            if(currentLength < closest_length):
                closest_length = currentLength
                closest_index = j
        pined_baked_points.push_back(closest_index)
    return pined_baked_points

func _process(delta):
    update()
    pass

func _draw():
	if(!Engine.editor_hint):
		var array = calculate_points_from_bodies_polyline(rigid_bodies)
		points = array
	else:
		var array = calculate_points_from_points_polyline(curve.get_baked_points())
		points = array

func calculate_points_from_bodies(bodies):
    var array = []
    for i in range(0, bodies.size() - 1):
        var last = null
        var current = null
        var next = null

        var last_pos = null
        var current_pos = null
        var next_pos = null

        if(i > 0):
            last = bodies[i-1]
            last_pos = last.get_position()
        current = bodies[i]
        next = bodies[i+1]

        current_pos = current.get_position()
        next_pos = next.get_position()


        var up = null
        var down = null

        if(last != null):
            var back_vector = (last_pos - current_pos)
            var front_vector = (next_pos - current_pos)
            var angle = rad2deg(back_vector.angle_to(front_vector))

            if(angle < 120 && angle > -120):
                down = (back_vector + front_vector).normalized() * (width / 2)
                up = Vector2(-down.x, -down.y)
                down += current.get_position()
                up += current.get_position()
                if(angle < 0):
                    var tmp = up
                    up = down
                    down = tmp
            else:
                var current_vector = Vector2(1, 0).rotated(current.get_rotation())
                down = get_down_pos(current.get_position(), current_vector)
                up = get_up_pos(current.get_position(), current_vector)
        else:
            var current_vector = Vector2(1, 0).rotated(current.get_rotation())
            down = get_down_pos(current.get_position(), current_vector)
            up = get_up_pos(current.get_position(), current_vector)

        array.push_back({up = up, down = down})
    return array

func calculate_points_from_bodies_polyline(bodies):
	var array = []
	for i in range(0, bodies.size()):
		var current = null
		current = bodies[i]
		array.append(current.get_position())
	return array

func calculate_points_from_points(points):
    var array = []
    for i in range(0, points.size() - 1):
        var last = null
        var current = null
        var next = null

        if(i > 0):
            last = points[i-1]
        current = points[i]
        next = points[i+1]

        var up = null
        var down = null

        if(last != null):
            var back_vector = (last - current)
            var front_vector = (next - current)
            var angle = rad2deg(back_vector.angle_to(front_vector))

            if(angle < 120 && angle > -120):
                down = (back_vector + front_vector).normalized() * (width / 2)
                up = Vector2(-down.x, -down.y)
                down += current
                up += current
                if(angle < 0):
                    var tmp = up
                    up = down
                    down = tmp
            else:
                front_vector = (next - current)
                angle = front_vector.angle()
                var current_vector = Vector2(1, 0).rotated(angle)
                down = get_down_pos(current, current_vector)
                up = get_up_pos(current, current_vector)
        else:
            var front_vector = (next - current)
            var angle = front_vector.angle()
            var current_vector = Vector2(1, 0).rotated(angle)
            down = get_down_pos(current, current_vector)
            up = get_up_pos(current, current_vector)

        array.push_back({up = up, down = down})
    return array

func calculate_points_from_points_polyline(points):
	var array = []
	for i in range(0, points.size()):
		var current = null
		current = points[i]
		array.append(current)
	return array

func draw_rope(array):
	for i in range(0, array.size() - 1):
		var current = array[i]
		var next = array[i + 1]
		draw_colored_polygon(PoolVector2Array([current.up, current.down, next.down, next.up]), default_color, uvs, texture, null, true)

func draw_rope_polyline(_line):
	draw_polyline(_line, default_color, width, true)

func get_down_pos(body_pos, body_normal_vector):
    return body_pos + Vector2(-body_normal_vector.y, body_normal_vector.x) * width/2

func get_up_pos(body_pos, body_normal_vector):
    return body_pos + Vector2(body_normal_vector.y, -body_normal_vector.x) * width/2

func get_end_pos(rigid_bodie):
    var shape = rigid_bodie.get_shape(0)
    var _position = Vector2(0, shape.get_extents().y)
    _position = _position.rotated(rigid_bodie.get_rot())
    return rigid_bodie.get_position() + _position
