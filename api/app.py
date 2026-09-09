from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/api/health")
def health():
    return jsonify({
        "service": "user-api",
        "status": "healthy"
    })


@app.route("/api/users")
def users():
    return jsonify({
        "service": "user-api",
        "users": [
            {
                "id": 1,
                "name": "John"
            },
            {
                "id": 2,
                "name": "Alice"
            }
        ]
    })


@app.route("/api/users/<int:user_id>")
def user(user_id):
    return jsonify({
        "id": user_id,
        "name": f"User-{user_id}"
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)