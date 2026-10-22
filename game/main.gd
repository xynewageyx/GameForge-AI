extends Node2D

var score: int = 0

func _ready() -> void:
    print("GameForge AI: starter ready")
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(30, 30, 350, 100), Color(0.12, 0.18, 0.29))
    draw_circle(Vector2(100, 80), 24, Color(0.35, 0.82, 0.56))

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        score += 1
        print("Touch score: ", score)
