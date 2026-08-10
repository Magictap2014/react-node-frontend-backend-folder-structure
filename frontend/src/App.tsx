import { ROUTES } from './routes/paths';
import './App.css';

function App() {
  const path = window.location.pathname;

  if (path === ROUTES.home) {
    return <div>Jigsaw Puzzle</div>;
  }

  return <div>Not found</div>;
}

export default App;
