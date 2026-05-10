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

// Listar tarefas
app.get("/tasks", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM tasks ORDER BY id DESC"
    );

    res.json(result.rows);
  } catch (error) {
    res.status(500).json({
      message: "Erro ao listar tarefas",
      error: error.message
    });
  }
});

// Criar tarefa
app.post("/tasks", async (req, res) => {
  try {
    const { title, description } = req.body;

    if (!title) {
      return res.status(400).json({
        message: "O título da tarefa é obrigatório"
      });
    }

    const result = await pool.query(
      "INSERT INTO tasks (title, description) VALUES ($1, $2) RETURNING *",
      [title, description || null]
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
    const { title, description, completed } = req.body;

    const result = await pool.query(
      `UPDATE tasks
       SET 
         title = COALESCE($1, title),
         description = COALESCE($2, description),
         completed = COALESCE($3, completed)
       WHERE id = $4
       RETURNING *`,
      [title, description, completed, id]
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