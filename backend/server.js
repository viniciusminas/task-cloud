const express = require("express");
const cors = require("cors");
require("dotenv").config();

const pool = require("./db");

const app = express();

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    message: "API de Cadastro de Tarefas rodando"
  });
});

app.get("/db-test", async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW()");
    res.json({
      status: "ok",
      database_time: result.rows[0].now
    });
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: "Erro ao conectar no banco de dados",
      error: error.message
    });
  }
});

// Listar usuários
app.get("/users", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM users ORDER BY name ASC"
    );

    res.json(result.rows);
  } catch (error) {
    res.status(500).json({
      message: "Erro ao listar usuários",
      error: error.message
    });
  }
});

// Criar usuário
app.post("/users", async (req, res) => {
  try {
    const { name, email } = req.body;

    if (!name || !email) {
      return res.status(400).json({
        message: "Nome e e-mail são obrigatórios"
      });
    }

    const result = await pool.query(
      "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *",
      [name, email]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({
      message: "Erro ao criar usuário",
      error: error.message
    });
  }
});

// Listar tarefas com responsável
app.get("/tasks", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT 
          tasks.id,
          tasks.user_id,
          tasks.title,
          tasks.description,
          tasks.completed,
          tasks.created_at,
          users.name AS user_name,
          users.email AS user_email
       FROM tasks
       LEFT JOIN users ON users.id = tasks.user_id
       ORDER BY tasks.id DESC`
    );

    res.json(result.rows);
  } catch (error) {
    res.status(500).json({
      message: "Erro ao listar tarefas",
      error: error.message
    });
  }
});

// Criar tarefa com responsável
app.post("/tasks", async (req, res) => {
  try {
    const { user_id, title, description } = req.body;

    if (!title) {
      return res.status(400).json({
        message: "O título da tarefa é obrigatório"
      });
    }

    const result = await pool.query(
      `INSERT INTO tasks (user_id, title, description) 
       VALUES ($1, $2, $3) 
       RETURNING *`,
      [user_id || null, title, description || null]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({
      message: "Erro ao criar tarefa",
      error: error.message
    });
  }
});

// Atualizar tarefa
app.put("/tasks/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { user_id, title, description, completed } = req.body;

    const result = await pool.query(
      `UPDATE tasks
       SET 
         user_id = COALESCE($1, user_id),
         title = COALESCE($2, title),
         description = COALESCE($3, description),
         completed = COALESCE($4, completed)
       WHERE id = $5
       RETURNING *`,
      [user_id, title, description, completed, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "Tarefa não encontrada"
      });
    }

    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({
      message: "Erro ao atualizar tarefa",
      error: error.message
    });
  }
});

// Excluir tarefa
app.delete("/tasks/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      "DELETE FROM tasks WHERE id = $1 RETURNING *",
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "Tarefa não encontrada"
      });
    }

    res.json({
      message: "Tarefa excluída com sucesso",
      task: result.rows[0]
    });
  } catch (error) {
    res.status(500).json({
      message: "Erro ao excluir tarefa",
      error: error.message
    });
  }
});

app.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});