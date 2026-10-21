import {
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { FilterQuery, Model, Types } from 'mongoose';
import { Category, CategoryDocument } from './schemas/category.schema';

interface SeedCategoryItem {
  name: string;
  slug: string;
  description: string;
  icon: string;
  sortOrder: number;
  parentSlug?: string;
}

export const INITIAL_CATEGORIES: SeedCategoryItem[] = [
  {
    name: 'Đồ điện tử',
    slug: 'electronics',
    description:
      'Tai nghe, loa bluetooth, máy ảnh, màn hình và thiết bị điện tử sinh viên.',
    icon: 'devices',
    sortOrder: 1,
  },
  {
    name: 'Máy tính & Phụ kiện',
    slug: 'computers-accessories',
    description:
      'Laptop, bàn phím cơ, chuột không dây, màn hình rời và phụ kiện góc học tập.',
    icon: 'computer',
    sortOrder: 2,
    parentSlug: 'electronics',
  },
  {
    name: 'Điện thoại & Máy tính bảng',
    slug: 'phones-tablets',
    description: 'Smartphone, iPad học tập, máy đọc sách Kindle, cáp sạc.',
    icon: 'smartphone',
    sortOrder: 3,
    parentSlug: 'electronics',
  },
  {
    name: 'Quần áo & Thời trang',
    slug: 'fashion',
    description: 'Áo khoác hoodie, balo laptop, giày thể thao, đồng phục.',
    icon: 'checkroom',
    sortOrder: 4,
  },
  {
    name: 'Đồ phòng trọ',
    slug: 'home-living',
    description:
      'Bàn học gỗ, ghế công thái học, đèn chống cận, kệ sách và đồ gia dụng phòng trọ.',
    icon: 'chair',
    sortOrder: 5,
  },
  {
    name: 'Sách & Giáo trình',
    slug: 'books',
    description:
      'Giáo trình đại cương, sách chuyên ngành CNTT/Kinh tế, tài liệu ôn thi TOEIC/IELTS.',
    icon: 'menu_book',
    sortOrder: 6,
  },
  {
    name: 'Phụ kiện & Khác',
    slug: 'sports-hobbies',
    description:
      'Máy tính bỏ túi Casio, nhạc cụ, dụng cụ thể thao và đồ dùng sinh viên khác.',
    icon: 'sports_soccer',
    sortOrder: 7,
  },
];

@Injectable()
export class CategoriesService implements OnModuleInit {
  private readonly logger = new Logger(CategoriesService.name);

  constructor(
    @InjectModel(Category.name)
    private readonly categoryModel: Model<CategoryDocument>,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.seedInitialCategories();
  }

  async seedInitialCategories(): Promise<void> {
    try {
      const slugToId = new Map<string, Types.ObjectId>();

      // First pass: upsert root categories idempotently
      for (const item of INITIAL_CATEGORIES.filter((c) => !c.parentSlug)) {
        const doc = await this.categoryModel
          .findOneAndUpdate(
            { slug: item.slug },
            {
              $set: {
                name: item.name,
                description: item.description,
                icon: item.icon,
                isActive: true,
                sortOrder: item.sortOrder,
              },
              $setOnInsert: {
                slug: item.slug,
                parentId: null,
              },
            },
            { upsert: true, new: true },
          )
          .exec();

        slugToId.set(item.slug, doc._id as Types.ObjectId);
      }

      // Second pass: upsert child categories with parentId reference
      for (const item of INITIAL_CATEGORIES.filter((c) => c.parentSlug)) {
        const parentId = item.parentSlug
          ? (slugToId.get(item.parentSlug) ?? null)
          : null;

        const doc = await this.categoryModel
          .findOneAndUpdate(
            { slug: item.slug },
            {
              $set: {
                name: item.name,
                description: item.description,
                icon: item.icon,
                parentId,
                isActive: true,
                sortOrder: item.sortOrder,
              },
              $setOnInsert: {
                slug: item.slug,
              },
            },
            { upsert: true, new: true },
          )
          .exec();

        slugToId.set(item.slug, doc._id as Types.ObjectId);
      }
    } catch (error) {
      this.logger.warn(
        `Category seed skipped or encountered warning: ${(error as Error).message}`,
      );
    }
  }

  async findAll(parentId?: string): Promise<CategoryDocument[]> {
    const filter: FilterQuery<CategoryDocument> = { isActive: true };

    if (parentId !== undefined) {
      if (parentId === 'root' || parentId === 'null') {
        filter.parentId = null;
      } else if (Types.ObjectId.isValid(parentId)) {
        filter.parentId = new Types.ObjectId(parentId);
      }
    }

    return this.categoryModel
      .find(filter)
      .sort({ sortOrder: 1, name: 1 })
      .exec();
  }

  async findById(id: string): Promise<CategoryDocument> {
    if (!Types.ObjectId.isValid(id)) {
      throw new NotFoundException('Category not found');
    }

    const category = await this.categoryModel.findById(id).exec();
    if (!category || !category.isActive) {
      throw new NotFoundException('Category not found');
    }

    return category;
  }

  async findBySlugOrId(identifier: string): Promise<CategoryDocument | null> {
    if (Types.ObjectId.isValid(identifier)) {
      return this.categoryModel
        .findOne({ _id: new Types.ObjectId(identifier), isActive: true })
        .exec();
    }

    return this.categoryModel
      .findOne({ slug: identifier.trim().toLowerCase(), isActive: true })
      .exec();
  }
}
