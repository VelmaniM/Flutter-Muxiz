import { Injectable, BadRequestException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: { email: string; password?: string; displayName?: string }) {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase().trim() },
    });

    if (existing) {
      throw new BadRequestException('User with this email already exists');
    }

    let passwordHash: string | null = null;
    if (dto.password) {
      passwordHash = await bcrypt.hash(dto.password, 10);
    }

    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase().trim(),
        displayName: dto.displayName || dto.email.split('@')[0],
        passwordHash,
        authProvider: 'local',
      },
    });

    const token = this.generateToken(user);
    return { user, token };
  }

  async login(dto: { email: string; password?: string }) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase().trim() },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.passwordHash && dto.password) {
      const match = await bcrypt.compare(dto.password, user.passwordHash);
      if (!match) {
        throw new UnauthorizedException('Invalid credentials');
      }
    }

    const token = this.generateToken(user);
    return { user, token };
  }

  async googleAuth(dto: { email: string; displayName?: string; photoURL?: string }) {
    const email = dto.email.toLowerCase().trim();
    let user = await this.prisma.user.findUnique({ where: { email } });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email,
          displayName: dto.displayName || email.split('@')[0],
          avatar: dto.photoURL || `https://ui-avatars.com/api/?name=${encodeURIComponent(dto.displayName || 'User')}&background=1DB954&color=000000`,
          authProvider: 'google',
        },
      });
    } else {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: {
          displayName: dto.displayName || user.displayName,
          avatar: dto.photoURL || user.avatar,
        },
      });
    }

    const token = this.generateToken(user);
    return { user, token };
  }

  async guestAuth(deviceId?: string) {
    const id = deviceId ? `guest_${deviceId.replace(/[^a-zA-Z0-9]/g, '').slice(0, 20)}` : `guest_${Date.now()}`;
    const email = `${id}@guest.muxiz.app`;

    let user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) {
      user = await this.prisma.user.create({
        data: {
          id,
          email,
          displayName: 'Guest Listener',
          avatar: `https://ui-avatars.com/api/?name=Guest+Listener&background=1DB954&color=000000`,
          authProvider: 'guest',
        },
      });
    }

    const token = this.generateToken(user);
    return { user, token };
  }

  async verifyToken(token: string) {
    try {
      const payload = this.jwtService.verify(token, {
        secret: process.env.JWT_SECRET || 'muxiz_super_secret_jwt_key_2026_production',
      });
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
      });
      if (!user) throw new UnauthorizedException('User not found');
      return { valid: true, user };
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }

  private generateToken(user: { id: string; email: string }) {
    return this.jwtService.sign(
      { sub: user.id, email: user.email },
      {
        secret: process.env.JWT_SECRET || 'muxiz_super_secret_jwt_key_2026_production',
        expiresIn: '90d',
      },
    );
  }
}
