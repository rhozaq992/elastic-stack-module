const express = require('express');

const app = express();
app.use(express.json());

let tasks = [];
let nextId = 1;

// Custom access log middleware -- NOT JSON, NOT Combined Log Format.
// Format: ts=<ISO8601>|method=<HTTP method>|path=<request path>|status=<HTTP status>|duration_ms=<int>|id=<resource id or ->
function accessLog(req, res, next) {
  const start = Date.now();
  res.on('finish', () => {
    const durationMs = Date.now() - start;
    const resourceId = req.params.id || res.locals.createdId || '-';
    const line = `ts=${new Date().toISOString()}|method=${req.method}|path=${req.path}|status=${res.statusCode}|duration_ms=${durationMs}|id=${resourceId}`;
    console.log(line);
  });
  next();
}

app.use(accessLog);

app.get('/health', (req, res) => res.status(200).send('OK'));

app.get('/tasks', (req, res) => {
  res.status(200).json(tasks);
});

app.get('/tasks/:id', (req, res) => {
  const task = tasks.find((t) => t.id === Number(req.params.id));
  if (!task) return res.status(404).json({ error: 'task not found' });
  res.status(200).json(task);
});

app.post('/tasks', (req, res) => {
  const { title } = req.body || {};
  if (!title) return res.status(400).json({ error: 'title is required' });
  const task = { id: nextId++, title, done: false };
  tasks.push(task);
  res.locals.createdId = task.id;
  res.status(201).json(task);
});

app.put('/tasks/:id', (req, res) => {
  const task = tasks.find((t) => t.id === Number(req.params.id));
  if (!task) return res.status(404).json({ error: 'task not found' });
  const { title, done } = req.body || {};
  if (title !== undefined) task.title = title;
  if (done !== undefined) task.done = done;
  res.status(200).json(task);
});

app.delete('/tasks/:id', (req, res) => {
  const idx = tasks.findIndex((t) => t.id === Number(req.params.id));
  if (idx === -1) return res.status(404).json({ error: 'task not found' });
  tasks.splice(idx, 1);
  res.status(204).send();
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`task-tracker listening on port ${PORT}`);
});
