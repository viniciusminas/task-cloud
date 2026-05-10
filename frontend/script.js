const API_URL = "http://localhost:3000";

const taskForm = document.getElementById("task-form");
const tasksList = document.getElementById("tasks-list");
const userSelect = document.getElementById("user_id");

async function loadUsers() {
  try {
    const response = await fetch(`${API_URL}/users`);
    const users = await response.json();

    userSelect.innerHTML = '<option value="">Selecione o responsável</option>';

    users.forEach((user) => {
      const option = document.createElement("option");
      option.value = user.id;
      option.textContent = `${user.name} (${user.email})`;
      userSelect.appendChild(option);
    });
  } catch (error) {
    console.error("Erro ao carregar usuários:", error);
  }
}

async function loadTasks() {
  try {
    const response = await fetch(`${API_URL}/tasks`);
    const tasks = await response.json();

    tasksList.innerHTML = "";

    if (tasks.length === 0) {
      tasksList.innerHTML = '<p class="empty-message">Nenhuma tarefa cadastrada.</p>';
      return;
    }

    tasks.forEach((task) => {
      const taskElement = document.createElement("div");
      taskElement.className = task.completed ? "task completed" : "task";

      taskElement.innerHTML = `
        <h3>${task.title}</h3>
        <p>${task.description || "Sem descrição"}</p>
        <p><strong>Responsável:</strong> ${task.user_name || "Não definido"}</p>
        <span class="badge ${task.completed ? "completed" : "pending"}">
        ${task.completed ? "Concluída" : "Pendente"}
        </span>
        <div class="task-actions">
          <button class="btn-complete" onclick="toggleTask(${task.id}, ${task.completed})">
            ${task.completed ? "Reabrir" : "Concluir"}
          </button>

          <button class="btn-delete" onclick="deleteTask(${task.id})">
            Excluir
          </button>
        </div>
      `;

      tasksList.appendChild(taskElement);
    });
  } catch (error) {
    tasksList.innerHTML = '<p class="empty-message">Erro ao carregar tarefas.</p>';
    console.error(error);
  }
}

taskForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  const user_id = document.getElementById("user_id").value;
  const title = document.getElementById("title").value;
  const description = document.getElementById("description").value;

  try {
    await fetch(`${API_URL}/tasks`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        user_id: user_id || null,
        title,
        description
      })
    });

    taskForm.reset();
    loadTasks();
  } catch (error) {
    alert("Erro ao cadastrar tarefa.");
    console.error(error);
  }
});

async function toggleTask(id, completed) {
  try {
    await fetch(`${API_URL}/tasks/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        completed: !completed
      })
    });

    loadTasks();
  } catch (error) {
    alert("Erro ao atualizar tarefa.");
    console.error(error);
  }
}

async function deleteTask(id) {
  try {
    await fetch(`${API_URL}/tasks/${id}`, {
      method: "DELETE"
    });

    loadTasks();
  } catch (error) {
    alert("Erro ao excluir tarefa.");
    console.error(error);
  }
}

loadUsers();
loadTasks();