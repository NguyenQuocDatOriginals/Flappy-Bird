import React, { useEffect, useRef } from 'react';
import './App.scss';

// Định nghĩa hằng số
const CANVAS_WIDTH = 400;
const CANVAS_HEIGHT = 600;
const BIRD_WIDTH = 50;
const BIRD_HEIGHT = 50;
const PIPE_WIDTH = 80;
const PIPE_GAP = 200;
const GRAVITY = 0.1;
const FLAP = -3;
const PIPE_SPEED = 1;

// Định nghĩa interface cho pipe
interface Pipe {
  x: number;
  topHeight: number;
  bottomHeight: number;
  scored: boolean;
}

const Game: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Tải hình ảnh
    const birdImg = new Image();
    birdImg.src = '/bird.png';
    const topPipeImg = new Image();
    topPipeImg.src = '/toppipe.png';
    const botPipeImg = new Image();
    botPipeImg.src = '/botpipe.png';
    const baseImg = new Image();
    baseImg.src = '/base.png';
    const backgroundImg = new Image();
    backgroundImg.src = '/background.png';

    // Khởi tạo biến trò chơi
    const bird = { x: 50, y: 150, width: BIRD_WIDTH, height: BIRD_HEIGHT, velocity: 0 };
    let pipes: Pipe[] = [];
    let score = 0;
    let gameState = 'start';

    // Xử lý đầu vào
    const handleInput = (event: KeyboardEvent | MouseEvent) => {
      if (
        (event instanceof KeyboardEvent && event.code === 'Space') ||
        event instanceof MouseEvent
      ) {
        if (gameState === 'start') {
          gameState = 'play';
        } else if (gameState === 'play') {
          bird.velocity = FLAP;
        } else if (gameState === 'end') {
          resetGame();
          gameState = 'play';
        }
      }
    };

    document.addEventListener('keydown', handleInput);
    document.addEventListener('click', handleInput);

    // Cập nhật logic trò chơi
    const update = () => {
      if (gameState === 'play') {
        bird.velocity += GRAVITY;
        bird.y += bird.velocity;

        pipes.forEach((pipe) => {
          pipe.x -= PIPE_SPEED;
        });

        if (pipes.length === 0 || pipes[pipes.length - 1].x < CANVAS_WIDTH - 300) {
          const topHeight = Math.random() * (CANVAS_HEIGHT - PIPE_GAP - 100) + 50;
          pipes.push({
            x: CANVAS_WIDTH,
            topHeight,
            bottomHeight: CANVAS_HEIGHT - topHeight - PIPE_GAP,
            scored: false,
          });
        }

        if (pipes[0] && pipes[0].x + PIPE_WIDTH < 0) {
          pipes.shift();
        }

        pipes.forEach((pipe) => {
          if (
            bird.x + bird.width > pipe.x &&
            bird.x < pipe.x + PIPE_WIDTH &&
            (bird.y < pipe.topHeight || bird.y + bird.height > CANVAS_HEIGHT - pipe.bottomHeight)
          ) {
            gameState = 'end';
          }
        });

        if (bird.y + bird.height > CANVAS_HEIGHT) {
          gameState = 'end';
        }

        pipes.forEach((pipe) => {
          if (!pipe.scored && bird.x > pipe.x + PIPE_WIDTH) {
            score++;
            pipe.scored = true;
          }
        });
      }
    };

    // Vẽ giao diện
    const draw = () => {
      if (!ctx) return;
      ctx.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
      ctx.drawImage(backgroundImg, 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);

      if (gameState === 'play') {
        pipes.forEach((pipe) => {
          ctx.drawImage(topPipeImg, pipe.x, 0, PIPE_WIDTH, pipe.topHeight);
          ctx.drawImage(botPipeImg, pipe.x, CANVAS_HEIGHT - pipe.bottomHeight, PIPE_WIDTH, pipe.bottomHeight);
        });

        ctx.drawImage(birdImg, bird.x, bird.y, bird.width, bird.height);

        ctx.fillStyle = 'white';
        ctx.font = '24px Arial';
        ctx.fillText(`Điểm: ${score}`, 10, 30);
      } else if (gameState === 'start') {
        ctx.fillStyle = 'white';
        ctx.font = '24px Arial';
        ctx.fillText('Nhấn để chơi', 125, 300);
      } else if (gameState === 'end') {
        ctx.fillStyle = 'white';
        ctx.font = '24px Arial';
        ctx.fillText('Bạn đã thua cuộc!', 103, 250);
        ctx.fillText(`Điểm: ${score}`, 160, 300);
        ctx.fillText('Nhấn để chơi lại', 110, 350);
      }

      ctx.drawImage(baseImg, 0, CANVAS_HEIGHT - 100, CANVAS_WIDTH, 100);
    };

    // Vòng lặp trò chơi
    const gameLoop = () => {
      update();
      draw();
      requestAnimationFrame(gameLoop);
    };
    gameLoop();

    // Khởi động lại trò chơi
    const resetGame = () => {
      bird.y = 150;
      bird.velocity = 0;
      pipes = [];
      score = 0;
    };

    // Dọn dẹp sự kiện
    return () => {
      document.removeEventListener('keydown', handleInput);
      document.removeEventListener('click', handleInput);
    };
  }, []);

  return <canvas ref={canvasRef} width={CANVAS_WIDTH} height={CANVAS_HEIGHT} />;
};

export default Game;