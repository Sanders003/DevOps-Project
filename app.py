from flask import Flask, render_template, redirect, url_for, request, flash
from flask_sqlalchemy import SQLAlchemy
from flask_login import (
    LoginManager,
    login_user,
    login_required,
    logout_user,
    UserMixin
)
import os

basedir = os.path.abspath(os.path.dirname(__file__))

app = Flask(__name__)
app.config["SECRET_KEY"] = "secretkey"
a = os.path.join(basedir, 'instance', 'app.db')
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + a

db = SQLAlchemy(app)
login_manager = LoginManager()
login_manager.login_view = "login"
login_manager.init_app(app)


class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)


@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))


@app.route("/")
def index():
    return redirect(url_for("login"))


@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]
        user = User(username=username, password=password)
        db.session.add(user)
        db.session.commit()
        flash("User registered. Please log in.")
        return redirect(url_for("login"))
    return render_template("register.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        user = User.query.filter_by(username=request.form["username"]).first()
        if user and user.password == request.form["password"]:
            login_user(user)
            return redirect(url_for("home"))
        flash("Invalid credentials.")
    return render_template("login.html")


@app.route("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for("login"))


@app.route("/home")
@login_required
def home():
    return render_template("index.html")


if __name__ == "__main__":
    os.makedirs("instance", exist_ok=True)
    with app.app_context():
        db.create_all()
    app.run(host="0.0.0.0", port=8000, debug=True)
