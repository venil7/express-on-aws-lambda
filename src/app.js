const express = require("express");
const app = express();

app.get("/", (req, res) => res.send("welcome to my API"));
app.get("/sum/:a/:b", (req, res) => {
  const a = parseFloat(req.params.a);
  const b = parseFloat(req.params.b);
  res.json({ sum: a + b });
});

module.exports = {
  app,
};

if (require.main === module) {
  app.listen(3000, () => console.log("listening.."));
}
